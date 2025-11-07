//
//  StationDetailView.swift
//  Riyadh Transport
//
//  Station detail view with arrivals
//

import SwiftUI
import MapKit

struct StationDetailView: View {
    let station: Station
    @State private var arrivals: [Arrival] = []
    @State private var isLoading = false
    @EnvironmentObject var favoritesManager: FavoritesManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Map preview
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: station.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [station]) { station in
                    MapMarker(coordinate: station.coordinate, tint: station.isMetro ? .blue : .green)
                }
                .frame(height: 200)
                .cornerRadius(10)
                .padding()
                
                // Station info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(station.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: toggleFavorite) {
                            Image(systemName: favoritesManager.isFavoriteStation(station) ? "star.fill" : "star")
                                .foregroundColor(.orange)
                                .font(.title2)
                        }
                    }
                    
                    HStack {
                        Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                            .foregroundColor(station.isMetro ? .blue : .green)
                        Text(station.type?.capitalized ?? "Station")
                            .foregroundColor(.secondary)
                    }
                    
                    if station.latitude != 0 && station.longitude != 0 {
                        Text("📍 \(String(format: "%.4f, %.4f", station.latitude, station.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Live arrivals
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("live_arrivals")
                            .font(.headline)
                        Spacer()
                        Button(action: loadArrivals) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if arrivals.isEmpty {
                        Text("no_arrivals")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(arrivals) { arrival in
                            ArrivalRow(arrival: arrival)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadArrivals)
    }
    
    private func toggleFavorite() {
        if favoritesManager.isFavoriteStation(station) {
            favoritesManager.removeFavoriteStation(station)
        } else {
            favoritesManager.addFavoriteStation(station)
        }
    }
    
    private func loadArrivals() {
        isLoading = true
        
        let loadArrivalsClosure = station.isMetro ? 
            APIService.shared.getMetroArrivals : 
            APIService.shared.getBusArrivals
        
        loadArrivalsClosure(station.rawName) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    parseArrivals(from: data)
                case .failure(let error):
                    print("Error loading arrivals: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func parseArrivals(from data: [String: Any]) {
        // Parse arrivals from API response
        // This is simplified - adjust based on actual API response
        var newArrivals: [Arrival] = []
        
        if let arrivalsData = data["arrivals"] as? [[String: Any]] {
            for arrivalData in arrivalsData {
                if let line = arrivalData["line"] as? String,
                   let destination = arrivalData["destination"] as? String,
                   let minutes = arrivalData["minutes"] as? Int {
                    let arrival = Arrival(line: line, destination: destination, minutesUntil: minutes)
                    newArrivals.append(arrival)
                }
            }
        }
        
        arrivals = newArrivals
    }
}

struct ArrivalRow: View {
    let arrival: Arrival
    
    var body: some View {
        HStack {
            // Line color
            RoundedRectangle(cornerRadius: 4)
                .fill(LineColorHelper.getMetroLineColor(arrival.line))
                .frame(width: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(arrival.line ?? "")
                    .font(.headline)
                Text(arrival.destination ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(arrival.minutesUntil ?? 0) min")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

#Preview {
    NavigationView {
        StationDetailView(station: Station(
            value: "test",
            label: "Test Station",
            name: "Test Station",
            type: "metro",
            lat: 24.7136,
            lng: 46.6753,
            distance: nil,
            duration: nil
        ))
        .environmentObject(FavoritesManager.shared)
    }
}
