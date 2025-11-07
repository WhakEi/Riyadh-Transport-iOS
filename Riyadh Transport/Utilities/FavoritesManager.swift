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

@MainActor
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteStations: [Station] = []
    @Published var favoriteLocations: [SearchResult] = []
    @Published var searchHistory: [SearchResult] = []
    
    private let favoritesKey = "FavoriteStations"
    private let locationsKey = "FavoriteLocations"
    private let historyKey = "SearchHistory"
    private let maxHistoryItems = 10
    
    private init() {
        loadFavorites()
    }
    
    // MARK: - Stations
    
    func addFavoriteStation(_ station: Station) {
        if !favoriteStations.contains(where: { $0.id == station.id }) {
            favoriteStations.append(station)
            saveFavorites()
        }
    }
    
    func removeFavoriteStation(_ station: Station) {
        favoriteStations.removeAll { $0.id == station.id }
        saveFavorites()
    }
    
    func isFavoriteStation(_ station: Station) -> Bool {
        return favoriteStations.contains { $0.id == station.id }
    }
    
    // MARK: - Locations
    
    func addFavoriteLocation(_ location: SearchResult) {
        if !favoriteLocations.contains(location) {
            favoriteLocations.append(location)
            saveLocations()
        }
    }
    
    func removeFavoriteLocation(_ location: SearchResult) {
        favoriteLocations.removeAll { $0 == location }
        saveLocations()
    }
    
    func removeFavoriteLocation(atOffsets offsets: IndexSet) {
        favoriteLocations.remove(atOffsets: offsets)
        saveLocations()
    }
    
    func isFavoriteLocation(_ location: SearchResult) -> Bool {
        return favoriteLocations.contains(location)
    }
    
    // MARK: - Search History
    
    func addToSearchHistory(_ result: SearchResult) {
        // Remove if already exists
        searchHistory.removeAll { $0 == result }
        
        // Add to beginning
        searchHistory.insert(result, at: 0)
        
        // Limit size
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveHistory()
    }
    
    func removeSearchHistory(atOffsets offsets: IndexSet) {
        searchHistory.remove(atOffsets: offsets)
        saveHistory()
    }
    
    // MARK: - Persistence
    
    private func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteStations) {
            UserDefaults.standard.set(encoded, forKey: favoritesKey)
        }
    }
    
    private func saveLocations() {
        // Now that SearchResult is Codable, we can use JSONEncoder.
        if let encoded = try? JSONEncoder().encode(favoriteLocations) {
            UserDefaults.standard.set(encoded, forKey: locationsKey)
        }
    }
    
    private func saveHistory() {
        // Now that SearchResult is Codable, we can use JSONEncoder.
        if let encoded = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadFavorites() {
        let decoder = JSONDecoder()
        
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let stations = try? decoder.decode([Station].self, from: data) {
            favoriteStations = stations
        }
        
        if let data = UserDefaults.standard.data(forKey: locationsKey),
           let locations = try? decoder.decode([SearchResult].self, from: data) {
            favoriteLocations = locations
        }
        
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? decoder.decode([SearchResult].self, from: data) {
            searchHistory = history
        }
    }
}
