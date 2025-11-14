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
                    Label(localizedString("watch_search_route_button"), systemImage: "map.fill")
                        .font(.headline)
                }
                
                NavigationLink(destination: WatchNearbyStationsView()) {
                    Label(localizedString("watch_stations_near_me_button"), systemImage: "location.circle.fill")
                        .font(.headline)
                }
            }
            .navigationTitle(localizedString("app_name"))
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
