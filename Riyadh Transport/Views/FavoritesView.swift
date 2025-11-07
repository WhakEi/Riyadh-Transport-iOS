//
//  FavoritesView.swift
//  Riyadh Transport
//
//  Favorites view
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var selectedSegment = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Segment control
            Picker("Favorites Type", selection: $selectedSegment) {
                Text("stations").tag(0)
                Text("locations").tag(1)
                Text("history").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            if selectedSegment == 0 {
                // Favorite stations
                if favoritesManager.favoriteStations.isEmpty {
                    emptyView(message: "no_favorite_stations")
                } else {
                    List {
                        ForEach(favoritesManager.favoriteStations) { station in
                            NavigationLink(destination: StationDetailView(station: station)) {
                                StationRow(station: station)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                favoritesManager.removeFavoriteStation(favoritesManager.favoriteStations[index])
                            }
                        }
                    }
                }
            } else if selectedSegment == 1 {
                // Favorite locations
                if favoritesManager.favoriteLocations.isEmpty {
                    emptyView(message: "no_favorite_locations")
                } else {
                    List {
                        ForEach(favoritesManager.favoriteLocations) { location in
                            LocationRow(location: location)
                        }
                        .onDelete { indexSet in
                            favoritesManager.removeFavoriteLocation(atOffsets: indexSet)
                        }
                    }
                }
            } else {
                // Search history
                if favoritesManager.searchHistory.isEmpty {
                    emptyView(message: "no_search_history")
                } else {
                    VStack(spacing: 0) {
                        Button(action: {
                            favoritesManager.clearSearchHistory()
                        }) {
                            Text("clear_history")
                                .foregroundColor(.red)
                        }
                        .padding()
                        
                        List {
                            ForEach(favoritesManager.searchHistory) { location in
                                LocationRow(location: location)
                            }
                            .onDelete { indexSet in
                                favoritesManager.removeSearchHistory(atOffsets: indexSet)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("favorites")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func emptyView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(message)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StationRow: View {
    let station: Station

    var body: some View {
        HStack {
            Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                .foregroundColor(station.isMetro ? .blue : .green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(station.displayName)
                    .font(.headline)
                Text(String(format: "%.4f, %.4f", station.latitude, station.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct LocationRow: View {
    let location: SearchResult
    
    var body: some View {
        HStack {
            Image(systemName: location.type == .recent ? "clock" : "mappin.circle.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.headline)
                Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        FavoritesView()
            .environmentObject(FavoritesManager.shared)
    }
}
