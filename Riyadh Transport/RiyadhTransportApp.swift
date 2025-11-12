//
//  RiyadhTransportApp.swift
//  Riyadh Transport
//
//  Main app entry point
//

import SwiftUI

@main
struct RiyadhTransportApp: App {
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"

    @StateObject private var locationManager = LocationManager()
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var stationManager = StationManager.shared
    @StateObject private var lineLoader = LineStationLoader()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(favoritesManager)
                .environmentObject(stationManager)
                .environmentObject(lineLoader)
                .environment(\.locale, Locale(identifier: selectedLanguage))
                .environment(\.layoutDirection, selectedLanguage == "ar" ? .rightToLeft : .leftToRight)
                .id(selectedLanguage)
                .onAppear {
                    // Trigger the migration and initial load once the app's UI is ready.
                    favoritesManager.performMigrationIfNeeded()
                    favoritesManager.loadFavorites()
                }
        }
    }
}
