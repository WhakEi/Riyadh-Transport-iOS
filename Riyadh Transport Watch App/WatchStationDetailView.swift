//
//  WatchStationDetailView.swift
//  Riyadh Transport Watch App
//
//  Station detail view with live arrivals for watchOS
//

import SwiftUI

// Extend LiveArrival to be Identifiable for watchOS views
extension LiveArrival: Identifiable {
    var id: String { "\(line)-\(destination)-\(minutesUntil)" }
}

struct WatchStationDetailView: View {
    let station: Station
    @State private var arrivals: [LiveArrival] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Station header
                VStack(spacing: 8) {
                    Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                        .font(.largeTitle)
                        .foregroundColor(station.isMetro ? .blue : .green)
                    
                    Text(station.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    
                    if let distance = station.distance {
                        let distanceInMeters = Int(distance)
                        Text("\(distanceInMeters)m away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
                .padding()
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Line indicator
                Circle()
                    .fill(lineColor)
                    .frame(width: 6, height: 6)
                
                Text(groupedArrival.line)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Soonest arrival time
                Text("\(groupedArrival.soonestArrival.minutesUntil) min")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(timeColor)
            }
            
            // Destination
            Text(groupedArrival.destination)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Upcoming arrivals
            if !groupedArrival.upcomingArrivals.isEmpty {
                HStack(spacing: 4) {
                    Text("Next:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ForEach(groupedArrival.upcomingArrivals, id: \.id) { arrival in
                        Text("\(arrival.minutesUntil)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
    
    private var lineColor: Color {
        // Simple color coding - can be enhanced with actual metro line colors
        if groupedArrival.line.contains("1") { return .blue }
        if groupedArrival.line.contains("2") { return .red }
        if groupedArrival.line.contains("3") { return .orange }
        if groupedArrival.line.contains("4") { return .yellow }
        if groupedArrival.line.contains("5") { return .green }
        if groupedArrival.line.contains("6") { return .purple }
        return .gray
    }
    
    private var timeColor: Color {
        let minutes = groupedArrival.soonestArrival.minutesUntil
        if minutes <= 2 { return .red }
        if minutes <= 5 { return .orange }
        return .primary
    }
}

#Preview {
    NavigationView {
        WatchStationDetailView(
            station: Station(
                rawName: "Test Station (Metro)",
                type: "metro",
                lat: 24.7136,
                lng: 46.6753
            )
        )
    }
}
