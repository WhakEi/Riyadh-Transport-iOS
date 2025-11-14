//
//  WatchNearbyStationsView.swift
//  Riyadh Transport Watch App
//
//  Nearby stations view with compass layout for watchOS
//

import SwiftUI
import CoreLocation

// MARK: - Models for Display
private struct Cluster: Identifiable, Equatable {
    let id = UUID()
    var stations: [Station]
}

private enum DisplayItem: Identifiable {
    case station(Station)
    case cluster(Cluster)
    
    var id: String {
        switch self {
        case .station(let station):
            return station.id
        case .cluster(let cluster):
            return cluster.id.uuidString
        }
    }
}

// MARK: - Main View
struct WatchNearbyStationsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationManager: StationManager
    @State private var nearbyStations: [Station] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView(localizedString("watch_finding_stations"))
            } else if let error = errorMessage {
                ErrorView(message: error, onRetry: loadNearbyStations)
            } else if nearbyStations.isEmpty {
                EmptyStateView(onRefresh: loadNearbyStations)
            } else {
                CompassView(
                    stations: nearbyStations,
                    userHeading: locationManager.heading
                )
            }
        }
        .navigationTitle(localizedString("nearby_stations"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
            loadNearbyStations()
        }
        .onDisappear {
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingHeading()
        }
    }
    
    private func loadNearbyStations() {
        guard let location = locationManager.location else {
            errorMessage = localizedString("watch_no_location_short")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if locationManager.location != nil {
                    loadNearbyStations()
                } else {
                    errorMessage = localizedString("watch_no_location")
                }
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let rawStations = try await APIService.shared.getNearbyStations(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                let stations = await MainActor.run {
                    stationManager.mergeNearbyStations(rawStations)
                }
                
                await MainActor.run {
                    self.nearbyStations = stations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = localizedString("watch_failed_to_load_stations")
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Helper Views for State
private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundColor(.orange)
            Text(message).font(.caption).multilineTextAlignment(.center).foregroundColor(.secondary)
            Button(localizedString("retry"), action: onRetry).padding(.top)
        }.padding()
    }
}

private struct EmptyStateView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash").font(.largeTitle).foregroundColor(.secondary)
            Text(localizedString("watch_no_stations_nearby")).font(.caption).foregroundColor(.secondary)
            Button(localizedString("watch_refresh"), action: onRefresh).padding(.top)
        }.padding()
    }
}

// MARK: - Compass View
struct CompassView: View {
    let stations: [Station]
    let userHeading: Double
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var zoomedCluster: Cluster? = nil
    @State private var zoomFocusPoint: CGPoint = .zero
    @State private var zoomLevel: CGFloat = 1.0
    
    private let zoomFactor: CGFloat = 3.0
    private let baseMaxDurationMinutes: Double = 15.0
    private let minDurationMinutes: Double = 2.0
    private let minRadiusFactor: CGFloat = 0.25
    private let baseClusterAngleThreshold: Double = 25.0

    private var filteredAndClusteredItems: [DisplayItem] {
        guard let userLocation = locationManager.location?.coordinate else { return [] }
        let currentMaxVisibleDuration = baseMaxDurationMinutes * zoomLevel
        let currentClusterThreshold = baseClusterAngleThreshold * zoomLevel
        let visibleStations = stations.filter { ($0.durationInSeconds / 60.0) <= currentMaxVisibleDuration }
        let sortedStations = visibleStations.sorted { calculateBearing(from: userLocation, to: $0.coordinate) < calculateBearing(from: userLocation, to: $1.coordinate) }
        
        var items: [DisplayItem] = []
        var currentCluster: Cluster?
        for station in sortedStations {
            if var cluster = currentCluster, let lastStation = cluster.stations.last {
                let bearing1 = calculateBearing(from: userLocation, to: lastStation.coordinate)
                let bearing2 = calculateBearing(from: userLocation, to: station.coordinate)
                if abs(bearing1 - bearing2) < currentClusterThreshold { cluster.stations.append(station); currentCluster = cluster }
                else { finalizeCluster(&items, &currentCluster); currentCluster = Cluster(stations: [station]) }
            } else { currentCluster = Cluster(stations: [station]) }
        }
        finalizeCluster(&items, &currentCluster)
        return items
    }
    
    private var minZoomLevel: CGFloat {
        guard let closestStationDuration = stations.min(by: { $0.durationInSeconds < $1.durationInSeconds })?.durationInSeconds else { return 0.2 }
        let closestStationMinutes = closestStationDuration / 60.0
        let effectiveClosestDuration = max(minDurationMinutes, closestStationMinutes)
        let calculatedMin = effectiveClosestDuration / baseMaxDurationMinutes
        return max(0.2, min(calculatedMin, 1.0))
    }
    
    private func finalizeCluster(_ items: inout [DisplayItem], _ cluster: inout Cluster?) {
        if let current = cluster {
            if current.stations.count > 1 { items.append(.cluster(current)) }
            else if let station = current.stations.first { items.append(.station(station)) }
        }
        cluster = nil
    }

    var body: some View {
        GeometryReader { geometry in
            let maxRadius = geometry.size.width * 0.4
            let currentMaxVisibleDuration = baseMaxDurationMinutes * zoomLevel
            
            ZStack {
                ZStack {
                    if zoomedCluster == nil {
                        ForEach(["N", "E", "S", "W"], id: \.self) { Text($0).font(.caption2).fontWeight(.bold).foregroundColor(.secondary).offset(y: -maxRadius * 1.1).rotationEffect(.degrees(cardinalAngle(for: $0))) }
                        
                        ForEach(filteredAndClusteredItems) { item in
                            switch item {
                            case .station(let station):
                                StationMarker(station: station, userLocation: locationManager.location?.coordinate, radius: calculateRadius(for: station, maxRadius: maxRadius, maxDuration: currentMaxVisibleDuration), isZoomed: false, zoomFactor: zoomFactor)
                            case .cluster(let cluster):
                                ClusterMarker(cluster: cluster, userLocation: locationManager.location?.coordinate, radius: calculateRadius(for: cluster.stations.first!, maxRadius: maxRadius, maxDuration: currentMaxVisibleDuration)) { cluster, centerPoint in
                                    zoomedCluster = cluster
                                    zoomFocusPoint = centerPoint
                                }
                            }
                        }
                    } else if let cluster = zoomedCluster {
                        ForEach(cluster.stations) { station in
                            StationMarker(station: station, userLocation: locationManager.location?.coordinate, radius: calculateRadius(for: station, maxRadius: maxRadius, maxDuration: baseMaxDurationMinutes), isZoomed: true, zoomFactor: zoomFactor)
                        }
                    }
                }
                .rotationEffect(.degrees(-userHeading))
                .scaleEffect(zoomedCluster != nil ? zoomFactor : 1.0, anchor: .center)
                .offset(x: -zoomFocusPoint.x * zoomFactor, y: -zoomFocusPoint.y * zoomFactor)
                .animation(.spring(), value: userHeading)
                .animation(.spring(), value: zoomedCluster)
                
                if zoomedCluster == nil {
                    UserLocationIndicator().allowsHitTesting(false)
                }
                
                if zoomedCluster != nil {
                    VStack { Spacer(); Button(action: { zoomedCluster = nil; zoomFocusPoint = .zero }) { Image(systemName: "arrow.down.right.and.arrow.up.left") }.padding(4).modifier(MaterialBackgroundModifier()) } // FIX: Use the modifier here
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .padding()
            .focusable()
            .digitalCrownRotation($zoomLevel, from: minZoomLevel, through: 1.0, by: 0.05, sensitivity: .medium)
        }
    }
    
    private func calculateRadius(for station: Station, maxRadius: CGFloat, maxDuration: Double) -> CGFloat {
        let durationMinutes = station.durationInSeconds / 60.0
        let clampedDuration = max(minDurationMinutes, min(durationMinutes, maxDuration))
        let range = maxDuration - minDurationMinutes
        let normalized = range > 0 ? (clampedDuration - minDurationMinutes) / range : 0
        let minRadius = maxRadius * minRadiusFactor
        return minRadius + (normalized * (maxRadius - minRadius))
    }
    
    private func cardinalAngle(for direction: String) -> Double {
        switch direction {
        case "N": return 0; case "E": return 90; case "S": return 180; case "W": return 270; default: return 0
        }
    }
}

// MARK: - UI Components
private struct UserLocationIndicator: View {
    var body: some View {
        ZStack {
            let flashlightShape = Path { path in path.move(to: .zero); path.addArc(center: .zero, radius: 60, startAngle: .degrees(-35), endAngle: .degrees(35), clockwise: false) }
            RadialGradient(gradient: Gradient(colors: [.blue.opacity(0.4), .blue.opacity(0.0)]), center: .center, startRadius: 0, endRadius: 60).clipShape(flashlightShape)
            Circle().fill(Color.white).frame(width: 14, height: 14)
            Circle().fill(Color.blue).frame(width: 12, height: 12)
        }.rotationEffect(.degrees(-90))
    }
}

private struct StationMarker: View {
    let station: Station
    let userLocation: CLLocationCoordinate2D?
    let radius: CGFloat
    let isZoomed: Bool
    let zoomFactor: CGFloat
    
    var body: some View {
        if let userLocation = userLocation {
            let bearing = calculateBearing(from: userLocation, to: station.coordinate)
            NavigationLink(destination: WatchStationDetailView(station: station)) {
                VStack(spacing: 2) {
                    Image(systemName: station.isMetro ? "tram.fill" : "bus.fill").font(.caption2).foregroundColor(station.isMetro ? .blue : .green).padding(4).modifier(MaterialBackgroundModifier())
                    Text(formatStationName(station.displayName)).font(.system(size: 8)).lineLimit(2).multilineTextAlignment(.center).frame(width: 40)
                }
                .scaleEffect(isZoomed ? 1.0 / zoomFactor : 1.0)
            }
            .buttonStyle(.plain)
            .offset(x: radius * cos((bearing - 90) * .pi / 180), y: radius * sin((bearing - 90) * .pi / 180))
        }
    }
}

private struct ClusterMarker: View {
    let cluster: Cluster
    let userLocation: CLLocationCoordinate2D?
    let radius: CGFloat
    let onTap: (Cluster, CGPoint) -> Void
    
    var body: some View {
        if let userLocation = userLocation, let firstStation = cluster.stations.first {
            let bearing = calculateBearing(from: userLocation, to: firstStation.coordinate)
            let offsetPoint = CGPoint(x: radius * cos((bearing - 90) * .pi / 180), y: radius * sin((bearing - 90) * .pi / 180))
            
            Button(action: { onTap(cluster, offsetPoint) }) {
                VStack(spacing: 2) {
                    Image(systemName: "circle.grid.2x2.fill").font(.caption2).foregroundColor(.orange).padding(4).modifier(MaterialBackgroundModifier())
                    Text(formatStationName(firstStation.displayName)).font(.system(size: 8)).lineLimit(2).multilineTextAlignment(.center).frame(width: 40)
                    Text(String(format: localizedString("watch_cluster_more"), cluster.stations.count - 1)).font(.system(size: 7)).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .offset(x: offsetPoint.x, y: offsetPoint.y)
        }
    }
}

// MARK: - Helpers
private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
    let lat1 = start.latitude * .pi / 180; let lat2 = end.latitude * .pi / 180
    let dLon = (end.longitude - start.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x) * 180 / .pi
    return (bearing + 360).truncatingRemainder(dividingBy: 360)
}

private func formatStationName(_ name: String) -> String {
    let characterLimit = 18
    if name.count <= characterLimit { return name }
    let regex = try! NSRegularExpression(pattern: "\\s(\\d{3})$")
    let range = NSRange(location: 0, length: name.utf16.count)
    if let match = regex.firstMatch(in: name, options: [], range: range) {
        let numberPart = (name as NSString).substring(with: match.range(at: 0))
        let namePart = (name as NSString).substring(to: match.range.location)
        let ellipsis = "..."
        let availableNameLength = characterLimit - numberPart.count - ellipsis.count
        if availableNameLength > 2 {
            let truncatedName = String(namePart.prefix(availableNameLength))
            return "\(truncatedName)\(ellipsis)\(numberPart)"
        } else { return numberPart.trimmingCharacters(in: .whitespaces) }
    } else { return name }
}

private struct MaterialBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 10.0, *) {
            content.background(.thinMaterial, in: Circle())
        } else {
            content.background(Color.gray.opacity(0.4), in: Circle())
        }
    }
}

#Preview {
    NavigationView {
        WatchNearbyStationsView()
            .environmentObject(LocationManager())
            .environmentObject(StationManager.shared)
    }
}
