import Foundation
import CoreLocation
import Combine

extension String {
    func strippedStationSuffix() -> String {
        return self
            .replacingOccurrences(of: "\\s*\\(Bus\\)\\s*$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s*\\(Metro\\)\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// Struct to represent a nearby station entry from /nearbystations (has no coordinates)
struct NearbyStationRaw: Codable {
    let name: String
    let type: String?
    let distance: Double?
    let duration: Double?
}

@MainActor
class StationManager: ObservableObject {
    static let shared = StationManager()
    
    @Published var stations: [Station] = []
    
    private init() {
        loadStations()
    }
    
    func loadStations() {
        // Guard against re-fetching data that's already loaded.
        guard stations.isEmpty else { return }

        Task {
            do {
                let loadedStations = try await APIService.shared.getStations()
                self.stations = loadedStations
                print("StationManager: Loaded \(self.stations.count) stations.")
            } catch {
                print("StationManager: Error loading stations: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
        }
    }
    
    /// Finds a station by matching its display name or raw name, normalizing suffixes.
    func findStation(byName name: String) -> Station? {
        let normalizedSearchKey = name.strippedStationSuffix()
        return stations.first { station in
            station.displayName.strippedStationSuffix().localizedCaseInsensitiveCompare(normalizedSearchKey) == .orderedSame ||
            station.rawName.strippedStationSuffix().localizedCaseInsensitiveCompare(normalizedSearchKey) == .orderedSame
        }
    }
    
    /// Given a list of raw nearby station entries, merges their distance/duration
    /// with the canonical coordinates/type from the full station list.
    func mergeNearbyStations(_ nearby: [NearbyStationRaw]) -> [Station] {
        nearby.compactMap { entry in
            if let masterStation = findStation(byName: entry.name) {
                // Use coordinates/type from master, but distance/duration from nearby
                return Station(
                    rawName: masterStation.rawName,
                    type: masterStation.type,
                    lat: masterStation.lat,
                    lng: masterStation.lng,
                    distance: entry.distance,
                    duration: entry.duration
                )
            } else {
                print("WARNING: Could not find canonical station for nearby entry: \(entry.name)")
                return nil // skip if no match
            }
        }
    }
}
