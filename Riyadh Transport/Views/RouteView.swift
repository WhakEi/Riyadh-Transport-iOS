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
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationManager: StationManager
    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var route: Route?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var showingStartSearch = false
    @State private var showingEndSearch = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Start location
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                    TextField("start_location", text: $startLocation)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onTapGesture {
                            showingStartSearch = true
                        }
                    Button(action: useCurrentLocation) {
                        Image(systemName: "location.fill")
                    }
                }
                .padding(.horizontal)

                // End location
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                    TextField("end_location", text: $endLocation)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                        .onTapGesture {
                            showingEndSearch = true
                        }
                }
                .padding(.horizontal)

                // Find route button
                Button(action: findRoute) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("find_route")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(isLoading)

                // Route results
                if let route = route {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("route_details")
                            .font(.headline)
                            .padding(.horizontal)

                        Text(String(format: NSLocalizedString("total_time", comment: ""), route.totalMinutes))
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
        .onSubmit {
            // Dismiss the keyboard when "Done" is tapped
            isTextFieldFocused = false
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
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
        .onChange(of: mapAction) { action in
            guard let action = action, let coordinate = mapTappedCoordinate else { return }
            
            switch action {
            case .setAsOrigin:
                startCoordinate = coordinate
                startLocation = formatCoordinate(coordinate)
            case .setAsDestination:
                endCoordinate = coordinate
                endLocation = formatCoordinate(coordinate)
            case .viewNearbyStations:
                break  // Handled in StationsView
            }
        }
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }

    private func useCurrentLocation() {
        locationManager.getCurrentLocation { location in
            guard let location = location else { return }
            let coordinate = location.coordinate
            startCoordinate = coordinate
            startLocation = NSLocalizedString("my_location", comment: "My Location")
        }
    }

    /// Tries to determine coordinates from a string, checking for "lat, lon" format, a station name, or falling back to a pre-selected coordinate.
    private func resolve(location: String, fallback: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)

        // Priority 1: Check if the string is raw coordinates.
        if let coords = parseCoordinates(from: trimmedLocation) {
            return coords
        }

        // Priority 2: Check if the string matches a known station.
        if let station = stationManager.findStation(byName: trimmedLocation) {
            return station.coordinate
        }

        // Priority 3: Use the coordinate that was set when the user picked a location from the search list.
        return fallback
    }

    /// Parses a string in "latitude,longitude" format into a `CLLocationCoordinate2D`.
    private func parseCoordinates(from string: String) -> CLLocationCoordinate2D? {
        let components = string.replacingOccurrences(of: " ", with: "").split(separator: ",")
        guard components.count == 2,
              let lat = Double(components[0]),
              let lon = Double(components[1]) else {
            return nil
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    private func findRoute() {
        let startString = startLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let endString = endLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !startString.isEmpty, !endString.isEmpty else {
            errorMessage = NSLocalizedString("select_locations", comment: "Please select start and end locations")
            showingError = true
            return
        }

        isLoading = true

        let resolvedStartCoord = resolve(location: startString, fallback: startCoordinate)
        let resolvedEndCoord = resolve(location: endString, fallback: endCoordinate)

        guard let startCoord = resolvedStartCoord, let endCoord = resolvedEndCoord else {
            errorMessage = NSLocalizedString("invalid_locations", comment: "Could not determine coordinates for one or more locations.")
            showingError = true
            isLoading = false
            return
        }

        print("Finding route from \(startCoord.latitude), \(startCoord.longitude) to \(endCoord.latitude), \(endCoord.longitude)")

        APIService.shared.findRoute(
            startLat: startCoord.latitude,
            startLng: startCoord.longitude,
            endLat: endCoord.latitude,
            endLng: endCoord.longitude
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let foundRoute):
                    print("Route found with \(foundRoute.segments.count) segments")
                    route = foundRoute
                case .failure(let error):
                    print("Route error: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct RouteSegmentRow: View {
    let segment: RouteSegment
    let nextSegment: RouteSegment?
    let isLastSegment: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Circle()
                .fill(LineColorHelper.getColorForSegment(type: segment.type, line: segment.line))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: iconForSegment)
                        .foregroundColor(.white)
                )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.headline)
                
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4) // Align text closer to the icon's vertical center

            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private var iconForSegment: String {
        if segment.isWalking {
            return "figure.walk"
        } else if segment.isMetro {
            return "tram.fill"
        } else if segment.isBus {
            return "bus.fill"
        }
        return "arrow.right"
    }
    
    private var titleText: String {
        // Walking
        if segment.isWalking {
            if isLastSegment {
                return NSLocalizedString("Walk to your destination", comment: "")
            } else if let nextStation = nextSegment?.stations?.first {
                return String(format: NSLocalizedString("Walk to %@", comment: ""), nextStation)
            } else {
                return NSLocalizedString("Walk", comment: "")
            }
        }

        // Bus/Metro
        if segment.isBus || segment.isMetro {
            var components: [String] = []
            let lineName = segment.line ?? ""
            if segment.isBus {
                let format = NSLocalizedString("Take Bus %@", comment: "e.g., Take Bus 150")
                components.append(String(format: format, lineName))
            } else {
                let format = NSLocalizedString("Take the %@", comment: "e.g., Take the Blue Line")
                components.append(String(format: format, lineName))
            }
            if let lastStation = segment.stations?.last {
                let format = NSLocalizedString("and Disembark at %@", comment: "e.g., and Disembark at KAFD")
                components.append(String(format: format, lastStation))
            }
            return components.joined(separator: " ")
        }
        
        return NSLocalizedString("Travel segment", comment: "")
    }
    
    private var subtitleText: String? {
        let durationMinutes = Int(round(segment.durationInSeconds / 60))
        
        var extras: [String] = []

        if segment.isBus || segment.isMetro {
            if let stationCount = segment.stations?.count, stationCount > 0 {
                // Use the new .stringsdict key for pluralization
                extras.append(String(format: NSLocalizedString("stops_count", comment: "Plural rule for stops"), stationCount))
            }
        }
        
        // Use the new .stringsdict key for pluralization
        extras.append(String(format: NSLocalizedString("minutes_count", comment: "Plural rule for minutes"), durationMinutes))

        return extras.isEmpty ? nil : extras.joined(separator: ", ")
    }
}


// Wrapper for preview to provide a FocusState binding
private struct RouteViewPreviewWrapper: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @FocusState private var isTextFieldFocused: Bool
    @State private var mapTappedCoordinate: CLLocationCoordinate2D?
    @State private var mapAction: MapTapAction?

    var body: some View {
        RouteView(
            region: $region,
            isTextFieldFocused: $isTextFieldFocused,
            mapTappedCoordinate: $mapTappedCoordinate,
            mapAction: $mapAction
        )
        .environmentObject(LocationManager())
        .environmentObject(StationManager.shared)
    }
}

#Preview {
    RouteViewPreviewWrapper()
}
