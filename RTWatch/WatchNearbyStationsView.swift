//
//  WatchNearbyStationsView.swift
//  Riyadh Transport Watch App
//
//  Nearby stations view with compass layout for watchOS
//

import SwiftUI
import CoreLocation

struct WatchNearbyStationsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var stationManager = StationManager.shared
    @State private var nearbyStations: [Station] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var heading: Double = 0.0
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Finding stations...")
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        loadNearbyStations()
                    }
                    .padding(.top)
                }
                .padding()
            } else if nearbyStations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No stations found nearby")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Refresh") {
                        loadNearbyStations()
                    }
                    .padding(.top)
                }
                .padding()
            } else {
                CompassView(
                    stations: nearbyStations,
                    userHeading: heading
                )
            }
        }
        .navigationTitle("Nearby Stations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.startUpdatingLocation()
            loadNearbyStations()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
        }
    }
    
    private func loadNearbyStations() {
        guard let location = locationManager.location else {
            errorMessage = "Unable to get your location"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Ensure station list is loaded
                if stationManager.stations.isEmpty {
                    stationManager.loadStations()
                    // Wait a bit for stations to load
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                // Fetch nearby stations from API
                let rawStations = try await APIService.shared.getNearbyStations(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                // Merge with canonical station data to get coordinates
                let stations = await MainActor.run {
                    stationManager.mergeNearbyStations(rawStations)
                }
                
                await MainActor.run {
                    self.nearbyStations = Array(stations.prefix(8)) // Limit to 8 stations for compass view
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load stations"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Compass View
struct CompassView: View {
    let stations: [Station]
    let userHeading: Double
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Compass circle background
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                
                // Cardinal directions
                ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                    Text(direction)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .offset(y: -(geometry.size.width * 0.45))
                        .rotationEffect(.degrees(cardinalAngle(for: direction)))
                }
                
                // Station markers
                ForEach(stations) { station in
                    StationMarker(
                        station: station,
                        userLocation: locationManager.location?.coordinate,
                        radius: geometry.size.width * 0.35
                    )
                }
                
                // User location indicator (center)
                VStack(spacing: 2) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    // Direction arrow showing where user is facing
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(userHeading))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding()
    }
    
    private func cardinalAngle(for direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

// MARK: - Station Marker
struct StationMarker: View {
    let station: Station
    let userLocation: CLLocationCoordinate2D?
    let radius: CGFloat
    @State private var showDetail = false
    
    var body: some View {
        if let userLocation = userLocation {
            let bearing = calculateBearing(
                from: userLocation,
                to: station.coordinate
            )
            
            NavigationLink(destination: WatchStationDetailView(station: station)) {
                VStack(spacing: 2) {
                    Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                        .font(.caption2)
                        .foregroundColor(station.isMetro ? .blue : .green)
                        .padding(4)
                        .background(Circle().fill(Color(UIColor.systemBackground)))
                    
                    Text(station.displayName.prefix(10))
                        .font(.system(size: 8))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 40)
                }
            }
            .buttonStyle(.plain)
            .offset(
                x: radius * CGFloat(sin(bearing * .pi / 180)),
                y: -radius * CGFloat(cos(bearing * .pi / 180))
            )
        }
    }
    
    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

#Preview {
    NavigationView {
        WatchNearbyStationsView()
            .environmentObject(LocationManager())
    }
}
