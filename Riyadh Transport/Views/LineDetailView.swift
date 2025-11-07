//
//  LineDetailView.swift
//  Riyadh Transport
//
//  Line detail view with stations
//

import SwiftUI

struct LineDetailView: View {
    let line: Line
    @State private var isLoading = false
    
    @State private var metroStations: [String] = []
    @State private var busStations: [String: [String]] = [:]
    @State private var busDirections: [String] = []
    @State private var selectedDirection: String = ""
    
    private var displayedStations: [String] {
        if line.isMetro {
            return metroStations
        } else {
            return busStations[selectedDirection] ?? []
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            lineHeader.padding()
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("stations").font(.headline).padding(.horizontal)
                    
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else if displayedStations.isEmpty {
                        Text("no_stations_available").foregroundColor(.secondary).padding()
                    } else {
                        ForEach(Array(displayedStations.enumerated()), id: \.offset) { index, stationName in
                            stationRow(stationName: stationName, index: index)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadStations)
    }
    
    private var lineHeader: some View {
        HStack(alignment: .top) { // Align to top for better picker layout
            RoundedRectangle(cornerRadius: 8)
                .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: line.isMetro ? "tram.fill" : "bus.fill").foregroundColor(.white).font(.title))

            VStack(alignment: .leading, spacing: 4) {
                Text(line.name ?? line.id).font(.title2).fontWeight(.bold)
                Text(line.type?.capitalized ?? "Line").foregroundColor(.secondary)
            }
            
            Spacer()
            
            // The new Menu-style picker, only visible for multi-direction bus routes.
            if line.isBus && busDirections.count > 1 {
                Menu {
                    ForEach(busDirections, id: \.self) { direction in
                        Button(action: {
                            selectedDirection = direction
                        }) {
                            Text(direction)
                        }
                    }
                } label: {
                    VStack { // Use a VStack for better label appearance
                        HStack {
                            Text(selectedDirection)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private func stationRow(stationName: String, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                    .frame(width: 32, height: 32)
                Text("\(index + 1)").foregroundColor(.white).font(.caption).fontWeight(.bold)
            }
            Text(stationName).font(.body)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func loadStations() {
        isLoading = true
        Task {
            do {
                if line.isMetro {
                    let fetchedStations = try await APIService.shared.getMetroStations(forLine: line.id)
                    await MainActor.run {
                        self.metroStations = fetchedStations
                    }
                } else {
                    let fetchedBusStations = try await APIService.shared.getBusStations(forLine: line.id)
                    await MainActor.run {
                        self.busStations = fetchedBusStations
                        self.busDirections = fetchedBusStations.keys.sorted()
                        if let firstDirection = self.busDirections.first {
                            self.selectedDirection = firstDirection
                        }
                    }
                }
            } catch {
                print("Error loading stations for line \(line.id): \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }
}

#Preview {
    NavigationView {
        LineDetailView(line: Line(id: "1", name: "Blue Line", type: "metro", color: nil, directions: nil, stationsByDirection: nil, routeSummary: nil))
    }
}
