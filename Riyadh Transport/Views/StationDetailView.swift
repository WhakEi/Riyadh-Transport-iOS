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
    @State private var arrivals: [LiveArrival] = []
    @State private var stationLines: StationLinesResponse?
    @State private var isLoadingArrivals = false
    @State private var isLoadingLines = false
    
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var lineLoader: LineStationLoader
    
    // Helper struct to group arrivals for display (FIX: 'private' removed)
    struct GroupedArrival: Identifiable {
        let id: String
        let line: String
        let destination: String
        let soonestArrival: LiveArrival
        let upcomingArrivals: [LiveArrival]
    }
    
    // Computed property to process and group the flat list of arrivals
    private var groupedArrivals: [GroupedArrival] {
        let groupedByLineAndDest = Dictionary(grouping: arrivals) { "\($0.line)-\($0.destination)" }
        
        return groupedByLineAndDest.values.compactMap { arrivalsInGroup -> GroupedArrival? in
            let sortedGroup = arrivalsInGroup.sorted { $0.minutesUntil < $1.minutesUntil }
            guard let soonest = sortedGroup.first else { return nil }
            
            let upcoming = Array(sortedGroup.dropFirst())
            
            return GroupedArrival(
                id: "\(soonest.line)-\(soonest.destination)",
                line: soonest.line,
                destination: soonest.destination,
                soonestArrival: soonest,
                upcomingArrivals: upcoming
            )
        }.sorted { $0.soonestArrival.minutesUntil < $1.soonestArrival.minutesUntil }
    }
    
    private var cleanStationName: String {
        return station.rawName.replacingOccurrences(of: "\\s*\\(Metro\\)|\\s*\\(Bus\\)$", with: "", options: .regularExpression)
    }
    
    var body: some View {
        List {
            Section {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: station.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [station]) { station in
                    MapMarker(coordinate: station.coordinate, tint: station.isMetro ? .blue : .green)
                }
                .frame(height: 200)
                .listRowInsets(EdgeInsets())

                stationInfo
            }

            Section(header: Text(localizedString("lines_in_station"))) {
                if isLoadingLines || lineLoader.isLoadingList {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let lines = stationLines, !lines.metroLines.isEmpty || !lines.busLines.isEmpty {
                    let servingLines = findServingLines(from: lines)
                    
                    if servingLines.isEmpty && (!lines.metroLines.isEmpty || !lines.busLines.isEmpty) {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        ForEach(servingLines) { line in
                            lineNavigationLink(for: line)
                        }
                    }
                } else {
                    Text(localizedString("no_lines_found")).foregroundColor(.secondary)
                }
            }
            
            Section(header: liveArrivalsHeader) {
                if isLoadingArrivals {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if arrivals.isEmpty {
                    Text(localizedString("no_arrivals")).foregroundColor(.secondary)
                } else {
                    ForEach(groupedArrivals) { arrivalGroup in
                        ArrivalRow(groupedArrival: arrivalGroup)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadArrivals()
            loadLines()
            lineLoader.loadLineList()
        }
    }
    
    private var stationInfo: some View {
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
                .buttonStyle(.plain)
            }
            
            HStack {
                Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                    .foregroundColor(station.isMetro ? .blue : .green)
                Text(localizedString(station.type ?? "station")).foregroundColor(.secondary)
            }
            
            if station.latitude != 0 && station.longitude != 0 {
                Text("📍 \(String(format: "%.4f, %.4f", station.latitude, station.longitude))")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var liveArrivalsHeader: some View {
        HStack {
            Text(localizedString("live_arrivals"))
            Spacer()
            Button(action: loadArrivals) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
    }
    
    @ViewBuilder
    private func lineNavigationLink(for line: Line) -> some View {
        let terminusString = terminus(for: line)
        if #available(iOS 16.0, *) {
            NavigationLink(value: line) {
                ServingLineRow(line: line, terminus: terminusString)
            }
        } else {
            NavigationLink(destination: LineDetailView(line: line)) {
                ServingLineRow(line: line, terminus: terminusString)
            }
        }
    }
    
    private func toggleFavorite() {
        if favoritesManager.isFavoriteStation(station) {
            favoritesManager.removeFavoriteStation(station)
        } else {
            favoritesManager.addFavoriteStation(station)
        }
    }
    
    private func findServingLines(from response: StationLinesResponse) -> [Line] {
        let allLineIDs = Set(response.metroLines + response.busLines)
        return lineLoader.lines.filter { allLineIDs.contains($0.id) }
    }
    
    private func terminus(for line: Line) -> String? {
        if line.isMetro {
            return line.routeSummary
        } else if line.isBus {
            let currentStationName = self.station.displayName.strippedStationSuffix()
            for (direction, stationsInDirection) in line.stationsByDirection ?? [:] {
                if stationsInDirection.contains(where: { $0.strippedStationSuffix() == currentStationName }) {
                    return direction
                }
            }
        }
        return nil
    }
    
    private func loadArrivals() {
        isLoadingArrivals = true
        Task {
            do {
                let response = try await LiveArrivalService.shared.fetchLiveArrivals(
                    stationName: station.rawName,
                    type: station.type ?? ""
                )
                
                await MainActor.run {
                    self.arrivals = response.arrivals
                }
            } catch {
                await MainActor.run {
                    print("Error loading live arrivals for '\(station.rawName)': \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                    self.arrivals = []
                }
            }
            await MainActor.run { isLoadingArrivals = false }
        }
    }
    
    private func loadLines() {
        guard stationLines == nil else { return }
        isLoadingLines = true
        Task {
            do {
                let lines = try await APIService.shared.getLinesForStation(stationName: cleanStationName)
                await MainActor.run {
                    self.stationLines = lines
                }
            } catch {
                print("Error loading lines for clean name '\(cleanStationName)': \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
            }
            await MainActor.run { isLoadingLines = false }
        }
    }
}

struct ArrivalRow: View {
    let groupedArrival: StationDetailView.GroupedArrival
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LineColorHelper.getMetroLineColor(groupedArrival.line))
                .frame(width: 8)
                
            VStack(alignment: .leading, spacing: 4) {
                Text(LineColorHelper.getMetroLineName(groupedArrival.line)).font(.headline)
                Text(groupedArrival.destination).font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
            
            let soonestMinutes = groupedArrival.soonestArrival.minutesUntil
            let upcomingMinutes = groupedArrival.upcomingArrivals.map { $0.minutesUntil }
            
            LiveArrivalIndicator(
                minutes: soonestMinutes,
                status: soonestMinutes < 59 ? "live" : "normal",
                upcomingArrivals: upcomingMinutes
            )
        }
    }
}

struct ServingLineRow: View {
    let line: Line
    let terminus: String?
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                .frame(width: 8, height: 40)
            Image(systemName: line.isMetro ? "tram.fill" : "bus.fill")
                .foregroundColor(line.isMetro ? .blue : .green)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(line.name ?? line.id).font(.headline)
                if let terminus = terminus, !terminus.isEmpty {
                    Text(terminus)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    NavigationView {
        StationDetailView(station: Station(
            rawName: "Test Station (Metro)",
            type: "metro",
            lat: 24.7136,
            lng: 46.6753
        ))
        .environmentObject(FavoritesManager.shared)
        .environmentObject(LineStationLoader())
    }
}
