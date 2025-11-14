//
//  WatchRouteView.swift
//  Riyadh Transport Watch App
//
//  Route planning view for watchOS - uses GPS as start, favorites/history as destination
//

import SwiftUI
import CoreLocation

// MARK: - Main View & Data Flow
struct WatchRouteView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    
    @State private var selectedDestination: SearchResult?
    @State private var route: Route?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDestinationPicker = false
    
    var body: some View {
        Group {
            if route != nil {
                RouteInstructionsView(route: $route)
            } else {
                VStack {
                    if isLoading {
                        ProgressView(localizedString("watch_finding_route"))
                    } else if let error = errorMessage {
                        Text(error).font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                        Button(localizedString("retry")) { showingDestinationPicker = true }.padding(.top, 8)
                    } else {
                        Text(localizedString("watch_select_destination")).foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(localizedString("watch_search_route_button"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if route == nil {
                DispatchQueue.main.async { showingDestinationPicker = true }
            }
        }
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(selectedDestination: $selectedDestination)
        }
        // FIX: Use older, compatible onChange syntax
        .onChange(of: selectedDestination) { newValue in
            if newValue != nil {
                findRoute()
            }
        }
    }
    
    private func findRoute() {
        guard let destination = selectedDestination else { return }
        Task {
            isLoading = true
            errorMessage = nil
            guard let userLocation = await locationManager.requestLocation() else {
                errorMessage = localizedString("watch_no_location"); isLoading = false; return
            }
            do {
                let foundRoute = try await APIService.shared.findRoute(startLat: userLocation.coordinate.latitude, startLng: userLocation.coordinate.longitude, endLat: destination.latitude, endLng: destination.longitude)
                await MainActor.run { self.route = foundRoute; self.isLoading = false; favoritesManager.addToSearchHistory(destination) }
            } catch {
                await MainActor.run { self.errorMessage = (error as? LocalizedError)?.errorDescription ?? localizedString("watch_route_not_found"); self.isLoading = false }
            }
        }
    }
}

// MARK: - Destination Picker View
struct DestinationPickerView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @Binding var selectedDestination: SearchResult?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !favoritesManager.favoriteLocations.isEmpty {
                    Section(header: Text(localizedString("favorites"))) { ForEach(favoritesManager.favoriteLocations) { location in Button(action: { select(location) }) { HStack { Image(systemName: "star.fill").foregroundColor(.orange).font(.caption); Text(location.name).font(.subheadline) } } } }
                }
                if !favoritesManager.favoriteStations.isEmpty {
                    Section(header: Text(localizedString("watch_favorite_stations"))) { ForEach(favoritesManager.favoriteStations) { station in let result = SearchResult(name: station.displayName, latitude: station.latitude, longitude: station.longitude, type: .station, stationId: station.id); Button(action: { select(result) }) { HStack { Image(systemName: station.isMetro ? "tram.fill" : "bus.fill").foregroundColor(station.isMetro ? .blue : .green).font(.caption); Text(station.displayName).font(.subheadline) } } } }
                }
                if !favoritesManager.searchHistory.isEmpty {
                    Section(header: Text(localizedString("recents"))) { ForEach(favoritesManager.searchHistory) { result in Button(action: { select(result) }) { HStack { Image(systemName: "clock").foregroundColor(.secondary).font(.caption); Text(result.name).font(.subheadline) } } } }
                }
                if favoritesManager.favoriteLocations.isEmpty && favoritesManager.favoriteStations.isEmpty && favoritesManager.searchHistory.isEmpty {
                    Text(localizedString("watch_no_favorites_or_history")).foregroundColor(.secondary).font(.subheadline)
                }
            }
            .navigationTitle(localizedString("watch_select_destination_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func select(_ result: SearchResult) { selectedDestination = result; dismiss() }
}

// MARK: - Route Instructions View (with Advanced Crown Scrolling)
struct RouteInstructionsView: View {
    @Binding var route: Route?
    @State private var currentPage = 0
    
    @State private var crownAccumulator: Double = 0.0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var isAtTop: Bool = true
    @State private var isAtBottom: Bool = false
    
    private var totalPages: Int {
        guard let route = route else { return 0 }
        return route.segments.count + 1
    }
    
    var body: some View {
        if let route = route {
            TabView(selection: $currentPage) {
                instructionPages(for: route)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .focusable()
            .digitalCrownRotation($crownAccumulator, from: -1, through: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            // FIX: Use older, compatible onChange syntax
            .onChange(of: crownAccumulator) { newValue in
                let scrollThreshold: Double = 0.5 

                if newValue > scrollThreshold {
                    if !isAtBottom {
                        scrollProxy?.scrollTo("bottom", anchor: .bottom)
                    } else if currentPage < totalPages - 1 {
                        currentPage += 1
                    }
                    crownAccumulator = 0
                } else if newValue < -scrollThreshold {
                    if !isAtTop {
                        scrollProxy?.scrollTo("top", anchor: .top)
                    } else if currentPage > 0 {
                        currentPage -= 1
                    }
                    crownAccumulator = 0
                }
            }
            // FIX: Use older, compatible onChange syntax
            .onChange(of: currentPage) { newValue in
                isAtTop = true
                isAtBottom = false
                crownAccumulator = 0
            }
        }
    }
    
    @ViewBuilder
    private func instructionPages(for route: Route) -> some View {
        ForEach(Array(route.segments.enumerated()), id: \.offset) { index, segment in
            ScrollViewReader { proxy in
                InstructionCard(
                    segment: segment,
                    nextSegment: (index + 1 < route.segments.count) ? route.segments[index + 1] : nil,
                    isLastSegment: index == route.segments.count - 1,
                    stepNumber: index + 1,
                    totalSteps: route.segments.count,
                    isAtTop: $isAtTop,
                    isAtBottom: $isAtBottom
                )
                .tag(index)
                .onAppear { self.scrollProxy = proxy }
            }
        }
        SummaryCard(route: route, onDismiss: { self.route = nil }).tag(route.segments.count)
    }
}

// MARK: - Instruction Card (Redesigned for Scrolling)
struct InstructionCard: View {
    let segment: RouteSegment
    let nextSegment: RouteSegment?
    let isLastSegment: Bool
    let stepNumber: Int
    let totalSteps: Int
    
    @Binding var isAtTop: Bool
    @Binding var isAtBottom: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Color.clear.frame(height: 0).id("top")
                Text(String(format: localizedString("watch_step_counter"), stepNumber, totalSteps)).font(.caption2).foregroundColor(.secondary).padding(.bottom, 2)
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: iconForSegment).font(.system(size: 28)).foregroundColor(colorForSegment).frame(width: 35)
                    VStack(alignment: .leading, spacing: 2) {
                        let minutes = Int(ceil(segment.durationInSeconds / 60))
                        Text(String(format: localizedString("minutes_short"), minutes)).font(.headline).fontWeight(.bold)
                        if segment.isBus || segment.isMetro, let stations = segment.stations, !stations.isEmpty { Text(String(format: localizedString("stops_count"), stations.count)).font(.caption).foregroundColor(.secondary) }
                    }
                    Spacer()
                }
                Text(instructionText).font(.body).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(height: 0).id("bottom")
            }
            .padding(.top, 0)
            .background(GeometryReader { geo in
                let frame = geo.frame(in: .named("scrollView"))
                Color.clear
                    .onAppear { updateScrollPosition(frame: frame, height: geo.size.height) }
                    // FIX: Use older, compatible onChange syntax
                    .onChange(of: frame) { newValue in
                        updateScrollPosition(frame: newValue, height: geo.size.height)
                    }
            })
        }
        .coordinateSpace(name: "scrollView")
    }
    
    private func updateScrollPosition(frame: CGRect, height: CGFloat) {
        isAtTop = frame.minY >= -1
        isAtBottom = frame.maxY <= height + 2
    }
    
    private var iconForSegment: String { if segment.isWalking { return "figure.walk" } else if segment.isMetro { return "tram.fill" } else if segment.isBus { return "bus.fill" } else { return "arrow.right" } }
    private var colorForSegment: Color { LineColorHelper.getColorForSegment(type: segment.type, line: segment.line) }
    
    private var instructionText: String {
        if segment.isWalking {
            if isLastSegment { return localizedString("route_walk_to_destination") } else if let nextStation = nextSegment?.stations?.first { return String(format: localizedString("route_walk_to_station"), nextStation) } else { return localizedString("walk") }
        }
        if segment.isBus || segment.isMetro {
            let lineIdentifier = segment.line ?? ""; let lastStation = segment.stations?.last ?? ""
            let localizedLineName = segment.isMetro ? LineColorHelper.getMetroLineName(lineIdentifier) : lineIdentifier
            if let refinedTerminus = segment.refinedTerminus, !refinedTerminus.isEmpty {
                let lineName = segment.isBus ? "Bus \(lineIdentifier)" : localizedLineName
                return String(format: localizedString("route_towards"), lineName, refinedTerminus, lastStation)
            } else {
                let takeInstructionFormat = localizedString(segment.isBus ? "route_take_bus" : "route_take_metro"); let disembarkInstructionFormat = localizedString("route_disembark_at")
                let takeInstruction = String(format: takeInstructionFormat, localizedLineName); let disembarkInstruction = String(format: disembarkInstructionFormat, lastStation)
                return "\(takeInstruction) \(disembarkInstruction)"
            }
        }
        return localizedString("route_travel_segment")
    }
}

// MARK: - Summary Card (Redesigned)
struct SummaryCard: View {
    let route: Route
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(.green)
                Text(localizedString("watch_route_summary")).font(.headline)
            }
            .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 10) {
                (Text(localizedString("watch_total_time")) + Text("\(route.totalMinutes) mins").foregroundColor(.secondary))
                let walkingSteps = route.segments.filter { $0.isWalking }.count
                let transitSteps = route.segments.count - walkingSteps
                Text(String(format: localizedString("watch_steps_breakdown"), transitSteps, walkingSteps))
            }
            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Button(localizedString("done"), action: onDismiss).buttonStyle(.bordered).tint(.blue)
        }
        .padding()
    }
}

#Preview {
    WatchRouteView()
        .environmentObject(LocationManager())
        .environmentObject(FavoritesManager.shared)
}
