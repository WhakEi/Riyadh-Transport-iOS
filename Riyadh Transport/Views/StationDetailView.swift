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
                        Text(localizedString("live_arrivals"))
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
                        Text(localizedString("no_arrivals"))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(arrivals) { arrival in
                            ArrivalRow(arrival: arrival, isMetro: station.isMetro)
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
        
        Task {
            do {
                let data: [String: Any]
                if station.isMetro {
                    data = try await APIService.shared.getMetroArrivals(stationName: station.rawName)
                } else {
                    data = try await APIService.shared.getBusArrivals(stationName: station.rawName)
                }
                
                await MainActor.run {
                    isLoading = false
                    parseArrivals(from: data)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    print("Error loading arrivals: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                    self.arrivals = []
                }
            }
        }
    }
    
    private func parseArrivals(from data: [String: Any]) {
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
        
        arrivals = newArrivals.sorted { $0.minutesUntil ?? 0 < $1.minutesUntil ?? 0 }
    }
}

struct ArrivalRow: View {
    let arrival: Arrival
    let isMetro: Bool
    
    private var localizedLineName: String {
        guard let line = arrival.line else { return "" }
        return isMetro ? LineColorHelper.getMetroLineName(line) : line
    }
    
    var body: some View {
        HStack {
            // Line color
            RoundedRectangle(cornerRadius: 4)
                .fill(LineColorHelper.getMetroLineColor(arrival.line))
                .frame(width: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedLineName)
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
