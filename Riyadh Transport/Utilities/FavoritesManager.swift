//
//  FavoritesManager.swift
//  Riyadh Transport
//
//  Manager for favorite locations and stations
//

import Foundation
import CoreLocation
import Combine
import SwiftUI
import WatchConnectivity // Import the framework

@MainActor
final class FavoritesManager: NSObject, ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteStations: [Station] = []
    @Published var favoriteLocations: [SearchResult] = []
    @Published var searchHistory: [SearchResult] = []
    
    private let appGroupIdentifier = "group.com.RTG.Riyadh-Transport"
    private var userDefaults: UserDefaults {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            fatalError("Could not open shared UserDefaults. Check App Group ID and entitlements configuration.")
        }
        return defaults
    }
    
    let favoritesKey = "FavoriteStations"
    let locationsKey = "FavoriteLocations"
    let historyKey = "SearchHistory"
    private let maxHistoryItems = 10
    private var didMigrateThisSession = false

    override public init() {
        super.init()
        #if os(iOS)
        performMigrationIfNeeded()
        #endif
        loadFavorites()
        
        #if os(iOS)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }
    
    #if os(iOS)
    public func performMigrationIfNeeded() {
        let standardDefaults = UserDefaults.standard
        let decoder = JSONDecoder(), encoder = JSONEncoder()
        let needsMigration = standardDefaults.data(forKey: favoritesKey) != nil || standardDefaults.data(forKey: locationsKey) != nil || standardDefaults.data(forKey: historyKey) != nil
        guard needsMigration else { return }
        print("FavoritesManager: Migrating old data...")
        var didChange = false
        if let oldData = standardDefaults.data(forKey: favoritesKey), let oldItems = try? decoder.decode([Station].self, from: oldData) {
            let currentData = userDefaults.data(forKey: favoritesKey), currentItems = (currentData != nil) ? (try? decoder.decode([Station].self, from: currentData!)) ?? [] : []
            if !oldItems.isEmpty {
                if let encoded = try? encoder.encode(Array(Set(currentItems + oldItems))) { userDefaults.set(encoded, forKey: favoritesKey); standardDefaults.removeObject(forKey: favoritesKey); didChange = true }
            }
        }
        if let oldData = standardDefaults.data(forKey: locationsKey), let oldItems = try? decoder.decode([SearchResult].self, from: oldData) {
            let currentData = userDefaults.data(forKey: locationsKey), currentItems = (currentData != nil) ? (try? decoder.decode([SearchResult].self, from: currentData!)) ?? [] : []
            if !oldItems.isEmpty {
                if let encoded = try? encoder.encode(Array(Set(currentItems + oldItems))) { userDefaults.set(encoded, forKey: locationsKey); standardDefaults.removeObject(forKey: locationsKey); didChange = true }
            }
        }
        if let oldData = standardDefaults.data(forKey: historyKey), let oldItems = try? decoder.decode([SearchResult].self, from: oldData) {
            let currentData = userDefaults.data(forKey: historyKey), currentItems = (currentData != nil) ? (try? decoder.decode([SearchResult].self, from: currentData!)) ?? [] : []
            if !oldItems.isEmpty {
                if let encoded = try? encoder.encode(Array(Set(currentItems + oldItems))) { userDefaults.set(encoded, forKey: historyKey); standardDefaults.removeObject(forKey: historyKey); didChange = true }
            }
        }
        if didChange { didMigrateThisSession = true; print("FavoritesManager: Migration complete.") }
    }
    #else
    public func performMigrationIfNeeded() {}
    #endif

    func addFavoriteStation(_ station: Station) { if !favoriteStations.contains(where: { $0.id == station.id }) { favoriteStations.append(station); saveFavorites() } }
    func removeFavoriteStation(_ station: Station) { favoriteStations.removeAll { $0.id == station.id }; saveFavorites() }
    func isFavoriteStation(_ station: Station) -> Bool { return favoriteStations.contains { $0.id == station.id } }
    func addFavoriteLocation(_ location: SearchResult) { if !favoriteLocations.contains(location) { favoriteLocations.append(location); saveLocations() } }
    func removeFavoriteLocation(_ location: SearchResult) { favoriteLocations.removeAll { $0 == location }; saveLocations() }
    func removeFavoriteLocation(atOffsets offsets: IndexSet) { favoriteLocations.remove(atOffsets: offsets); saveLocations() }
    func isFavoriteLocation(_ location: SearchResult) -> Bool { return favoriteLocations.contains(location) }
    func addToSearchHistory(_ result: SearchResult) { searchHistory.removeAll { $0 == result }; searchHistory.insert(result, at: 0); if searchHistory.count > maxHistoryItems { searchHistory = Array(searchHistory.prefix(maxHistoryItems)) }; saveHistory() }
    func clearSearchHistory() { searchHistory.removeAll(); saveHistory() }
    func removeSearchHistory(atOffsets offsets: IndexSet) { searchHistory.remove(atOffsets: offsets); saveHistory() }

    private func saveFavorites() { if let encoded = try? JSONEncoder().encode(favoriteStations) { userDefaults.set(encoded, forKey: favoritesKey); syncContextWithWatch() } }
    private func saveLocations() { if let encoded = try? JSONEncoder().encode(favoriteLocations) { userDefaults.set(encoded, forKey: locationsKey); syncContextWithWatch() } }
    private func saveHistory() { if let encoded = try? JSONEncoder().encode(searchHistory) { userDefaults.set(encoded, forKey: historyKey); syncContextWithWatch() } }
    
    public func loadFavorites() {
        let decoder = JSONDecoder()
        if let data = userDefaults.data(forKey: favoritesKey), let items = try? decoder.decode([Station].self, from: data) { favoriteStations = items } else { favoriteStations = [] }
        if let data = userDefaults.data(forKey: locationsKey), let items = try? decoder.decode([SearchResult].self, from: data) { favoriteLocations = items } else { favoriteLocations = [] }
        if let data = userDefaults.data(forKey: historyKey), let items = try? decoder.decode([SearchResult].self, from: data) { searchHistory = items } else { searchHistory = [] }
    }
    
    public func update(from context: [String: Any]) {
        // --- THIS IS THE FIX ---
        // Force the entire body of this function to run on the main thread.
        DispatchQueue.main.async {
            let decoder = JSONDecoder()
            print("Updating FavoritesManager on thread: \(Thread.current)") // This will now print "main"
            
            if let data = context[self.favoritesKey] as? Data, let items = try? decoder.decode([Station].self, from: data) {
                self.favoriteStations = items
            }
            if let data = context[self.locationsKey] as? Data, let items = try? decoder.decode([SearchResult].self, from: data) {
                self.favoriteLocations = items
            }
            if let data = context[self.historyKey] as? Data, let items = try? decoder.decode([SearchResult].self, from: data) {
                self.searchHistory = items
            }
            
            // Save the newly received data to the watch's own store (on the main thread)
            self.saveFavorites(); self.saveLocations(); self.saveHistory()
        }
    }

    #if os(iOS)
    private func syncContextWithWatch() {
        guard WCSession.default.activationState == .activated else { return }
        
        var context: [String: Any] = ["lastUpdated": Date()]
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(favoriteStations) { context[favoritesKey] = data }
        if let data = try? encoder.encode(favoriteLocations) { context[locationsKey] = data }
        if let data = try? encoder.encode(searchHistory) { context[historyKey] = data }
        
        do {
            try WCSession.default.updateApplicationContext(context)
            print("FavoritesManager: Sent full data context to watch.")
        } catch {
            print("FavoritesManager: Error sending context: \(error.localizedDescription)")
        }
    }
    #else
    private func syncContextWithWatch() {}
    #endif
}

#if os(iOS)
extension FavoritesManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error { print("WCSession activation failed: \(error.localizedDescription)"); return }
        if activationState == .activated { syncContextWithWatch() } // Sync on activation
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
#endif
