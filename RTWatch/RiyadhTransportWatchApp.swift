//
//  RiyadhTransportWatchApp.swift
//  Riyadh Transport Watch App
//
//  watchOS companion app entry point
//

import SwiftUI

@main
struct RiyadhTransportWatchApp: App {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var stationManager = StationManager.shared
    
    // The connectivity manager is now an ObservableObject
    @StateObject private var connectivityManager = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(locationManager)
                .environmentObject(favoritesManager)
                .environmentObject(stationManager)
                .onAppear {
                    stationManager.loadStations()
                }
                // --- THIS IS THE FIX ---
                // Watch for the signal from the connectivity manager
                .onChange(of: connectivityManager.needsReload) { _ in
                    print("App received reload signal. Calling loadFavorites().")
                    favoritesManager.loadFavorites()
                }
        }
    }
}
