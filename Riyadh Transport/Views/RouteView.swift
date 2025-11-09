//
//  RouteView.swift
//  Riyadh Transport
//
//  Route planning view
//

import SwiftUI
import MapKit

struct RouteView: View {
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var mapTappedCoordinate: CLLocationCoordinate2D?
    @Binding var mapAction: MapTapAction?
    @Binding var displayedRoute: Route?
    
    @Binding var startLocation: String
    @Binding var endLocation: String
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?
    
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationManager: StationManager
    
    @State private var route: Route?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    @State private var showingStartSearch = false
    @State private var showingEndSearch = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                LocationFieldButton(
                    placeholder: "start_location",
                    text: $startLocation,
                    imageName: "circle.fill",
                    imageColor: .green
                )
                .onTapGesture { showingStartSearch = true }
                
                LocationFieldButton(
                    placeholder: "end_location",
                    text: $endLocation,
                    imageName: "mappin.circle.fill",
                    imageColor: .red
                )
                .onTapGesture { showingEndSearch = true }

                HStack {
                    Button(action: useCurrentLocation) {
                        Label(localizedString("use_location"), systemImage: "location.fill")
                    }
                    Spacer()
                }
                .padding(.horizontal)

                Button(action: findRoute) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(localizedString("find_route"))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .contentShape(Rectangle())
                .padding(.horizontal)
                .disabled(isLoading)

                if let route = route {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localizedString("route_details"))
                            .font(.headline)
                            .padding(.horizontal)

                        Text(String(format: localizedString("total_time"), route.totalMinutes))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        ForEach(Array(route.segments.enumerated()), id: \.offset) { index, segment in
                            let nextSegment = (index + 1 < route.segments.count) ? route.segments[index + 1] : nil
                            let isLastSegment = index == route.segments.count - 1
                            
                            RouteSegmentRow(
                                segment: segment,
                                nextSegment: nextSegment,
                                isLastSegment: isLastSegment
                            )
                        }
                    }
                    .padding(.top)
                }
            }
            .padding(.vertical)
        }
        .alert(localizedString("error"), isPresented: $showingError) {
            Button(localizedString("ok"), role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingStartSearch) {
            SearchLocationView(isPresented: $showingStartSearch) { result in
                startLocation = result.name
                startCoordinate = result.coordinate
            }
        }
        .sheet(isPresented: $showingEndSearch) {
            SearchLocationView(isPresented: $showingEndSearch) { result in
                endLocation = result.name
                endCoordinate = result.coordinate
            }
        }
        .onAppear {
            handleMapAction()
        }
    }
    
    private func handleMapAction() {
        guard let action = mapAction, let coordinate = mapTappedCoordinate else { return }
        
        switch action {
        case .setAsOrigin:
            startCoordinate = coordinate
            startLocation = formatCoordinate(coordinate)
        case .setAsDestination:
            endCoordinate = coordinate
            endLocation = formatCoordinate(coordinate)
        case .viewNearbyStations:
            return
        }
        mapAction = nil
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    // This function is now updated to use the modern async/await API.
    private func useCurrentLocation() {
        Task {
            if let location = await locationManager.requestLocation() {
                await MainActor.run {
                    self.startCoordinate = location.coordinate
                    self.startLocation = localizedString("my_location")
                }
            }
        }
    }

    private func resolve(location: String, fallback: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if let coords = parseCoordinates(from: trimmedLocation) { return coords }
        if let station = stationManager.findStation(byName: trimmedLocation) { return station.coordinate }
        return fallback
    }

    private func parseCoordinates(from string: String) -> CLLocationCoordinate2D? {
        let components = string.replacingOccurrences(of: " ", with: "").split(separator: ",")
        guard components.count == 2, let lat = Double(components[0]), let lon = Double(components[1]) else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private func findRoute() {
        let startString = startLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let endString = endLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !startString.isEmpty, !endString.isEmpty else {
            errorMessage = localizedString("select_locations")
            showingError = true
            return
        }

        guard let startCoord = resolve(location: startString, fallback: startCoordinate),
              let endCoord = resolve(location: endString, fallback: endCoordinate) else {
            errorMessage = localizedString("invalid_locations")
            showingError = true
            return
        }

        isLoading = true
        
        Task {
            do {
                let foundRoute = try await APIService.shared.findRoute(
                    startLat: startCoord.latitude, startLng: startCoord.longitude,
                    endLat: endCoord.latitude, endLng: endCoord.longitude
                )
                await MainActor.run {
                    isLoading = false
                    self.route = foundRoute
                    self.displayedRoute = foundRoute
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    let localizedError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.errorMessage = localizedError
                    self.showingError = true
                    self.route = nil
                    self.displayedRoute = nil
                }
            }
        }
    }
}

// LocationFieldButton and RouteSegmentRow remain unchanged...

struct LocationFieldButton: View {
    let placeholder: String
    @Binding var text: String
    let imageName: String
    let imageColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: imageName).foregroundColor(imageColor)
            Text(text.isEmpty ? localizedString(placeholder) : text)
                .foregroundColor(text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
        }.padding(.horizontal)
    }
}

struct RouteSegmentRow: View {
    let segment: RouteSegment
    let nextSegment: RouteSegment?
    let isLastSegment: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(LineColorHelper.getColorForSegment(type: segment.type, line: segment.line))
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: iconForSegment).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline)
                if let subtitle = subtitleText {
                    Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                }
            }.padding(.vertical, 4)
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var iconForSegment: String {
        if segment.isWalking { return "figure.walk" }
        if segment.isMetro { return "tram.fill" }
        if segment.isBus { return "bus.fill" }
        return "arrow.right"
    }
    
    private var titleText: String {
        if segment.isWalking {
            if isLastSegment {
                return localizedString("route_walk_to_destination")
            } else if let nextStation = nextSegment?.stations?.first {
                return String(format: localizedString("route_walk_to_station"), nextStation)
            } else {
                return localizedString("walk")
            }
        }

        if segment.isBus || segment.isMetro {
            let lineIdentifier = segment.line ?? ""
            let lastStation = segment.stations?.last ?? ""
            
            let localizedLineName = segment.isMetro ? LineColorHelper.getMetroLineName(lineIdentifier) : lineIdentifier
            
            let takeInstructionFormat = localizedString(segment.isBus ? "route_take_bus" : "route_take_metro")
            let disembarkInstructionFormat = localizedString("route_disembark_at")
            
            let takeInstruction = String(format: takeInstructionFormat, localizedLineName)
            let disembarkInstruction = String(format: disembarkInstructionFormat, lastStation)
            
            return "\(takeInstruction) \(disembarkInstruction)"
        }
        
        return localizedString("route_travel_segment")
    }
    
    private var subtitleText: String? {
        let durationMinutes = Int(round(segment.durationInSeconds / 60))
        var extras: [String] = []
        
        if segment.isBus || segment.isMetro, let stationCount = segment.stations?.count, stationCount > 0 {
            if stationCount == 1 {
                extras.append(localizedString("one_stop"))
            } else {
                extras.append(String(format: localizedString("stops_count"), stationCount))
            }
        }
        
        if durationMinutes == 1 {
            extras.append(localizedString("one_minute"))
        } else if durationMinutes > 1 {
            extras.append(String(format: localizedString("minutes_count"), durationMinutes))
        }
        
        return extras.isEmpty ? nil : extras.joined(separator: ", ")
    }
}

#Preview { RouteViewPreviewWrapper() }

private struct RouteViewPreviewWrapper: View {
    @State private var region = MKCoordinateRegion()
    @FocusState private var isTextFieldFocused: Bool
    @State private var mapTappedCoordinate: CLLocationCoordinate2D?
    @State private var mapAction: MapTapAction?
    @State private var displayedRoute: Route?
    
    @State private var startLocation = ""
    @State private var endLocation = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        RouteView(
            region: $region, isTextFieldFocused: $isTextFieldFocused,
            mapTappedCoordinate: $mapTappedCoordinate, mapAction: $mapAction,
            displayedRoute: $displayedRoute,
            startLocation: $startLocation,
            endLocation: $endLocation,
            startCoordinate: $startCoordinate,
            endCoordinate: $endCoordinate
        )
        .environmentObject(LocationManager())
        .environmentObject(StationManager.shared)
    }
}
