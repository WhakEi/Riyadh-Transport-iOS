// Create a new Swift file named StationManager.swift and add this code.
import Foundation
import CoreLocation
import Combine

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

        APIService.shared.getStations { result in
            // UI updates must happen on the main thread.
            DispatchQueue.main.async {
                switch result {
                case .success(let loadedStations):
                    self.stations = loadedStations
                    print("StationManager: Loaded \(self.stations.count) stations.")
                case .failure(let error):
                    print("StationManager: Error loading stations: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Finds a station by matching its display name or raw name.
    func findStation(byName name: String) -> Station? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return stations.first { station in
            station.displayName.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame ||
            station.rawName.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }
}
