//
//  WatchStationDetailView.swift
//  Riyadh Transport Watch App
//
//  Station detail view with live arrivals for watchOS
//

import SwiftUI

// Extend LiveArrival to be Identifiable for watchOS views
extension LiveArrival: Identifiable {
    // Use a UUID for a guaranteed unique ID in SwiftUI lists
    var id: String { UUID().uuidString }
}

struct WatchStationDetailView: View {
    let station: Station
    @State private var arrivals: [LiveArrival] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // FIX: Redesigned header to be more compact
                HStack(spacing: 12) {
                    Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                        .font(.title)
                        .foregroundColor(station.isMetro ? .blue : .green)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading) {
                        Text(station.displayName)
                            .font(.headline)
                        
                        if let distance = station.distance {
                            let distanceInMeters = Int(distance)
                            Text("\(distanceInMeters)m away")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Live arrivals section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Live Arrivals")
                            .font(.headline)
                        Spacer()
                        Button(action: loadArrivals) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding()
                    } else if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    } else if arrivals.isEmpty {
                        Text("No arrivals available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(groupedArrivals.prefix(5)) { group in
                            ArrivalRow(groupedArrival: group)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Station Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadArrivals()
        }
    }
    
    // Group arrivals by line and destination, showing the closest arrival
    private var groupedArrivals: [GroupedArrival] {
        let groupedByLineAndDest = Dictionary(grouping: arrivals) { "\($0.line)-\($0.destination)" }
        
        return groupedByLineAndDest.values.compactMap { arrivalsInGroup -> GroupedArrival? in
            let sortedGroup = arrivalsInGroup.sorted { $0.minutesUntil < $1.minutesUntil }
            guard let soonest = sortedGroup.first else { return nil }
            
            let upcoming = Array(sortedGroup.dropFirst().prefix(2)) // Show up to 2 upcoming
            
            return GroupedArrival(
                id: "\(soonest.line)-\(soonest.destination)",
                line: soonest.line,
                destination: soonest.destination,
                soonestArrival: soonest,
                upcomingArrivals: upcoming
            )
        }.sorted { $0.soonestArrival.minutesUntil < $1.soonestArrival.minutesUntil }
    }
    
    private func loadArrivals() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await LiveArrivalService.shared.fetchLiveArrivals(
                    stationName: station.rawName,
                    type: station.type ?? ""
                )
                
                await MainActor.run {
                    self.arrivals = response.arrivals
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load arrivals"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Grouped Arrival Model
struct GroupedArrival: Identifiable {
    let id: String
    let line: String
    let destination: String
    let soonestArrival: LiveArrival
    let upcomingArrivals: [LiveArrival]
}

// MARK: - Arrival Row
struct ArrivalRow: View {
    let groupedArrival: GroupedArrival
    
    var body: some View {
        HStack(alignment: .center) {
            // Left Side: Line color bar, name, and destination
            Rectangle()
                .fill(LineColorHelper.getMetroLineColor(groupedArrival.line))
                .frame(width: 4, height: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(LineColorHelper.getMetroLineName(groupedArrival.line))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(groupedArrival.destination)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right Side: The unified LiveArrivalIndicator
            let soonestMinutes = groupedArrival.soonestArrival.minutesUntil
            let upcomingMinutes = groupedArrival.upcomingArrivals.map { $0.minutesUntil }
            
            LiveArrivalIndicator(
                minutes: soonestMinutes,
                status: soonestMinutes < 59 ? "live" : "normal",
                upcomingArrivals: upcomingMinutes
            )
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        WatchStationDetailView(
            station: Station(
                rawName: "Test Station (Metro)",
                type: "metro",
                lat: 24.7136,
                lng: 46.6753,
                distance: 150,
                duration: nil
            )
        )
    }
}
