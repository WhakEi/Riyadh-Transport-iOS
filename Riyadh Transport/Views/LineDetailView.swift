//
//  LineDetailView.swift
//  Riyadh Transport
//
//  Line detail view with stations
//

import SwiftUI

struct LineDetailView: View {
    let line: Line
    @State private var stations: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Line header
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: line.isMetro ? "tram.fill" : "bus.fill")
                                .foregroundColor(.white)
                                .font(.title)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.name ?? line.id)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(line.type?.capitalized ?? "Line")
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Route summary
                if let routeSummary = line.routeSummary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("route")
                            .font(.headline)
                        Text(routeSummary)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                // Stations list
                VStack(alignment: .leading, spacing: 12) {
                    Text("stations")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if stations.isEmpty {
                        Text("no_stations")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(stations.enumerated()), id: \.offset) { index, stationName in
                            HStack(spacing: 12) {
                                // Station number
                                ZStack {
                                    Circle()
                                        .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                                        .frame(width: 32, height: 32)
                                    Text("\(index + 1)")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                
                                Text(stationName)
                                    .font(.body)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadStations)
    }
    
    private func loadStations() {
        // Load stations for this line
        // This is simplified - in a real app, you'd fetch from API
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Mock data - replace with actual API call
            if line.isMetro {
                stations = generateMetroStations(for: line.id)
            } else {
                stations = generateBusStations(for: line.id)
            }
            isLoading = false
        }
    }
    
    private func generateMetroStations(for lineId: String) -> [String] {
        // Mock metro stations - replace with actual API data
        switch lineId {
        case "1":
            return ["Olaya", "Al Malaz", "King Abdullah Financial District", "Diriyah"]
        case "2":
            return ["King Abdullah Road", "Western Ring Road", "Airport", "King Khalid"]
        case "3":
            return ["Qasr Al Hukm", "Sahafa", "Al Aqiq", "Khurais"]
        default:
            return []
        }
    }
    
    private func generateBusStations(for lineId: String) -> [String] {
        // Mock bus stations - replace with actual API data
        return ["Station 1", "Station 2", "Station 3", "Station 4"]
    }
}

#Preview {
    NavigationView {
        LineDetailView(line: Line(
            id: "1",
            name: "Blue Line",
            type: "metro",
            color: nil,
            directions: nil,
            stationsByDirection: nil,
            routeSummary: "Olaya - Diriyah"
        ))
    }
}
