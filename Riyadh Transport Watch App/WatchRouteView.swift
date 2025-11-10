//
//  WatchRouteView.swift
//  Riyadh Transport Watch App
//
//  Route planning view for watchOS - uses GPS as start, favorites/history as destination
//

import SwiftUI
import CoreLocation

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
            if route == nil {
                destinationSelectionView
            } else {
                RouteInstructionsView(route: $route)
            }
        }
        .navigationTitle("Search Route")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var destinationSelectionView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Starting point (always user location)
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.green)
                        Text("My Location")
                            .font(.subheadline)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(8)
                }
                
                // Destination picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: { showingDestinationPicker = true }) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                            Text(selectedDestination?.name ?? "Select Destination")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Find route button
                if selectedDestination != nil {
                    Button(action: findRoute) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Find Route")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(isLoading)
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingDestinationPicker) {
            DestinationPickerView(selectedDestination: $selectedDestination)
        }
    }
    
    private func findRoute() {
        guard let destination = selectedDestination else { return }
        guard let userLocation = locationManager.location else {
            errorMessage = "Unable to get your location"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let foundRoute = try await APIService.shared.findRoute(
                    startLat: userLocation.coordinate.latitude,
                    startLng: userLocation.coordinate.longitude,
                    endLat: destination.latitude,
                    endLng: destination.longitude
                )
                
                await MainActor.run {
                    self.route = foundRoute
                    self.isLoading = false
                    
                    // Add to search history
                    favoritesManager.addToSearchHistory(destination)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Route not found"
                    self.isLoading = false
                }
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
                // Favorites
                if !favoritesManager.favoriteLocations.isEmpty {
                    Section(header: Text("Favorites")) {
                        ForEach(favoritesManager.favoriteLocations) { location in
                            Button(action: {
                                selectedDestination = location
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text(location.name)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                
                // Favorite Stations
                if !favoritesManager.favoriteStations.isEmpty {
                    Section(header: Text("Favorite Stations")) {
                        ForEach(favoritesManager.favoriteStations) { station in
                            Button(action: {
                                selectedDestination = SearchResult(
                                    name: station.displayName,
                                    latitude: station.latitude,
                                    longitude: station.longitude,
                                    type: .station,
                                    stationId: station.id
                                )
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                                        .foregroundColor(station.isMetro ? .blue : .green)
                                        .font(.caption)
                                    Text(station.displayName)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                
                // Search History
                if !favoritesManager.searchHistory.isEmpty {
                    Section(header: Text("Recent")) {
                        ForEach(favoritesManager.searchHistory) { result in
                            Button(action: {
                                selectedDestination = result
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text(result.name)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                
                // Empty state
                if favoritesManager.favoriteLocations.isEmpty &&
                   favoritesManager.favoriteStations.isEmpty &&
                   favoritesManager.searchHistory.isEmpty {
                    Text("No favorites or history")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Route Instructions View
struct RouteInstructionsView: View {
    @Binding var route: Route?
    @State private var currentPage = 0
    
    private var totalPages: Int {
        guard let route = route else { return 0 }
        return route.segments.count + 1 // +1 for summary page
    }
    
    var body: some View {
        VStack {
            if let route = route {
                TabView(selection: $currentPage) {
                    // Instruction pages
                    ForEach(Array(route.segments.enumerated()), id: \.offset) { index, segment in
                        InstructionCard(
                            segment: segment,
                            stepNumber: index + 1,
                            totalSteps: route.segments.count
                        )
                        .tag(index)
                    }
                    
                    // Summary page
                    SummaryCard(
                        route: route,
                        onDismiss: { self.route = nil }
                    )
                    .tag(route.segments.count)
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Instruction Card
struct InstructionCard: View {
    let segment: RouteSegment
    let stepNumber: Int
    let totalSteps: Int
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Step indicator
                Text("Step \(stepNumber) of \(totalSteps)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Icon
                Image(systemName: iconForSegment)
                    .font(.system(size: 40))
                    .foregroundColor(colorForSegment)
                    .padding()
                
                // Instruction text
                Text(instructionText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Duration and details
                VStack(spacing: 4) {
                    if let duration = segment.duration {
                        let minutes = Int(ceil(duration / 60))
                        Text("\(minutes) min")
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    
                    if segment.isBus || segment.isMetro, let stations = segment.stations, !stations.isEmpty {
                        Text("\(stations.count) stop(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
            }
            .padding()
        }
    }
    
    private var iconForSegment: String {
        if segment.isWalking { return "figure.walk" }
        if segment.isMetro { return "tram.fill" }
        if segment.isBus { return "bus.fill" }
        return "arrow.right"
    }
    
    private var colorForSegment: Color {
        if segment.isWalking { return .gray }
        if segment.isMetro { return .blue }
        if segment.isBus { return .green }
        return .primary
    }
    
    private var instructionText: String {
        if segment.isWalking {
            if let firstStation = segment.stations?.first {
                return "Walk to \(firstStation)"
            }
            return "Walk"
        }
        
        if segment.isBus || segment.isMetro {
            let lineId = segment.line ?? ""
            let lastStation = segment.stations?.last ?? ""
            
            if segment.isBus {
                return "Take Bus \(lineId) to \(lastStation)"
            } else {
                return "Take Metro Line \(lineId) to \(lastStation)"
            }
        }
        
        return "Continue"
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let route: Route
    let onDismiss: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Route Summary")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(route.totalMinutes) min")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                
                VStack(spacing: 4) {
                    Text("\(route.segments.count) steps")
                        .font(.subheadline)
                    
                    let walkingSteps = route.segments.filter { $0.isWalking }.count
                    let transitSteps = route.segments.count - walkingSteps
                    
                    if transitSteps > 0 {
                        Text("\(transitSteps) transit, \(walkingSteps) walking")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: onDismiss) {
                    Text("Return to Menu")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
            }
            .padding()
        }
    }
}

#Preview {
    WatchRouteView()
        .environmentObject(LocationManager())
        .environmentObject(FavoritesManager.shared)
}
