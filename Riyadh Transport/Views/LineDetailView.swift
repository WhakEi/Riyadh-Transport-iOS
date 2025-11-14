//
//  LineDetailView.swift
//  Riyadh Transport
//
//  Line detail view with stations
//

import SwiftUI

struct LineDetailView: View {
    let line: Line
    
    @EnvironmentObject var stationManager: StationManager
    
    @State private var selectedDirection: String = ""
    @State private var showDirectionDialog = false
    @State private var alerts: [LineAlert] = []
    @State private var isLoadingAlerts = false
    
    private var busDirections: [String] { line.stationsByDirection?.keys.sorted() ?? [] }
    private var isRingRoute: Bool { line.isBus && busDirections.count == 1 }
    
    private var displayedStations: [String] {
        if line.isMetro {
            return line.stationsByDirection?["main"] ?? []
        } else {
            return line.stationsByDirection?[selectedDirection] ?? []
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            lineHeader.padding()
            Divider()
            
            List {
                // Alerts section
                if !alerts.isEmpty {
                    Section {
                        ForEach(alerts) { alert in
                            LineAlertView(alert: alert)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                        }
                    }
                }
                
                Section(header: Text(localizedString("stations")).font(.headline)) {
                    if displayedStations.isEmpty {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        ForEach(Array(displayedStations.enumerated()), id: \.offset) { index, stationName in
                            if let station = stationManager.findStation(byName: stationName) {
                                if #available(iOS 16.0, *) {
                                    NavigationLink(value: station) {
                                        stationRow(stationName: stationName, index: index)
                                    }
                                } else {
                                    NavigationLink(destination: StationDetailView(station: station)) {
                                        stationRow(stationName: stationName, index: index)
                                    }
                                }
                            } else {
                                stationRow(stationName: stationName, index: index)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // If not set, set to the first direction available
            if selectedDirection.isEmpty, let firstDirection = busDirections.first {
                selectedDirection = firstDirection
            }
            loadAlerts()
        }
        .onChange(of: busDirections) { newDirections in
            // If the available directions change and the selected direction is missing, set it to the first
            if !newDirections.isEmpty && !newDirections.contains(selectedDirection) {
                selectedDirection = newDirections.first ?? ""
            }
        }
        .confirmationDialog(localizedString("choose_direction"), isPresented: $showDirectionDialog, titleVisibility: .visible) {
            ForEach(busDirections, id: \.self) { direction in
                Button(direction) { selectedDirection = direction }
            }
        }
    }
    
    private var lineHeader: some View {
        HStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8).fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: line.isMetro ? "tram.fill" : "bus.fill").foregroundColor(.white).font(.title))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(line.name ?? line.id).font(.title2).fontWeight(.bold)
                Text(localizedString(line.type ?? "line")).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isRingRoute {
                Text(line.routeSummary ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            else if line.isBus && busDirections.count > 1 {
                if #available(iOS 16.0, *) {
                    Menu {
                        ForEach(busDirections, id: \.self) { direction in
                            Button(action: { selectedDirection = direction }) {
                                Text(direction)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedDirection)
                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                } else {
                    Button(action: { showDirectionDialog = true }) {
                        HStack {
                            Text(selectedDirection)
                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                    .disabled(busDirections.isEmpty)
                }
            }
        }
    }
    
    private func stationRow(stationName: String, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                    .frame(width: 32, height: 32)
                Text("\(index + 1)").foregroundColor(.white).font(.caption).fontWeight(.bold)
            }
            Text(stationName).font(.body)
            Spacer()
        }.padding(.vertical, 4)
    }
    
    private func loadAlerts() {
        isLoadingAlerts = true
        
        Task {
            do {
                // Get alerts for this specific line
                let fetchedAlerts = try await LineAlertService.shared.getAlertsForLine(line.id)
                
                await MainActor.run {
                    self.alerts = fetchedAlerts
                    self.isLoadingAlerts = false
                }
            } catch {
                await MainActor.run {
                    print("Error loading alerts for line \(line.id): \(error.localizedDescription)")
                    self.alerts = []
                    self.isLoadingAlerts = false
                }
            }
        }
    }
}

