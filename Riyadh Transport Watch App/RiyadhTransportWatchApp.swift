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
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(locationManager)
                .environmentObject(favoritesManager)
        }
    }
}
