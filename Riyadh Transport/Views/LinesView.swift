//
//  LinesView.swift
//  Riyadh Transport
//
//  Lines browsing view
//

import SwiftUI

struct LinesView: View {
    @State private var metroLines: [Line] = []
    @State private var busLines: [Line] = []
    @State private var isLoading = false
    @State private var selectedSegment = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Metro/Bus selector
            Picker("Line Type", selection: $selectedSegment) {
                Text("metro").tag(0)
                Text("bus").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Lines list
            if isLoading {
                ProgressView()
                    .padding()
            } else {
                List(selectedSegment == 0 ? metroLines : busLines) { line in
                    NavigationLink(destination: LineDetailView(line: line)) {
                        LineRow(line: line)
                    }
                }
                .listStyle(.plain)
            }
        }
        .onAppear(perform: loadLines)
    }
    
    private func loadLines() {
        isLoading = true
        
        // Load metro lines
        APIService.shared.getMetroLines { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    parseMetroLines(from: data)
                case .failure(let error):
                    print("Error loading metro lines: \(error.localizedDescription)")
                }
            }
        }
        
        // Load bus lines
        APIService.shared.getBusLines { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    parseBusLines(from: data)
                case .failure(let error):
                    print("Error loading bus lines: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func parseMetroLines(from data: [String: Any]) {
        // Parse metro lines from API response
        // This is a simplified version - adjust based on actual API response
        var lines: [Line] = []
        for i in 1...6 {
            let lineId = String(i)
            let lineName = LineColorHelper.getMetroLineName(lineId)
            let line = Line(id: lineId, name: lineName, type: "metro", color: nil, directions: nil, stationsByDirection: nil, routeSummary: nil)
            lines.append(line)
        }
        metroLines = lines
    }
    
    private func parseBusLines(from data: [String: Any]) {
        // Parse bus lines from API response
        // This is a simplified version - adjust based on actual API response
        var lines: [Line] = []
        if let linesData = data["lines"] as? [[String: Any]] {
            for lineData in linesData {
                if let id = lineData["id"] as? String,
                   let name = lineData["name"] as? String {
                    let line = Line(id: id, name: name, type: "bus", color: nil, directions: nil, stationsByDirection: nil, routeSummary: nil)
                    lines.append(line)
                }
            }
        }
        busLines = lines
    }
}

struct LineRow: View {
    let line: Line
    
    var body: some View {
        HStack {
            // Line color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                .frame(width: 8)
            
            // Line icon
            Circle()
                .fill(line.isMetro ? Color.blue : Color.green)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: line.isMetro ? "tram.fill" : "bus.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                )
            
            // Line info
            VStack(alignment: .leading, spacing: 4) {
                Text(line.name ?? line.id)
                    .font(.headline)
                Text(line.type?.capitalized ?? "Line")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        LinesView()
    }
}
