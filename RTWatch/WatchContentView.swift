//
//  WatchContentView.swift
//  Riyadh Transport Watch App
//
//  Main view for watchOS app with navigation to features
//

import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: WatchRouteView()) {
                    Label("Search Route", systemImage: "map.fill")
                        .font(.headline)
                }
                
                NavigationLink(destination: WatchNearbyStationsView()) {
                    Label("Stations Near Me", systemImage: "location.circle.fill")
                        .font(.headline)
                }
            }
            .navigationTitle("Riyadh Transport")
        }
        .onAppear {
            locationManager.requestPermission()
        }
    }
}

#Preview {
    WatchContentView()
        .environmentObject(LocationManager())
        .environmentObject(FavoritesManager.shared)
}
