//
//  LinesView.swift
//  Riyadh Transport
//
//  Lines browsing view
//

import SwiftUI

struct LinesView: View {
    @State private var allLines: [Line] = []
    @State private var metroLines: [Line] = []
    @State private var busLines: [Line] = []
    @State private var isLoading = false
    @State private var selectedSegment = 0 // 0: All, 1: Metro, 2: Bus
    
    private var displayedLines: [Line] {
        switch selectedSegment {
        case 0: return allLines
        case 1: return metroLines
        case 2: return busLines
        default: return []
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Line Type", selection: $selectedSegment) {
                Text(localizedString("all")).tag(0)
                Text(localizedString("metro")).tag(1)
                Text(localizedString("bus")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(displayedLines) { line in
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
        if let cachedMetro: [Line] = CacheManager.shared.loadData(forKey: CacheManager.metroLinesCacheKey, maxAgeInDays: 7),
           let cachedBus: [Line] = CacheManager.shared.loadData(forKey: CacheManager.busLinesCacheKey, maxAgeInDays: 7) {
            // If we load from cache, we still need to process for correct localization and sorting.
            processAndSortLines(metro: cachedMetro, bus: cachedBus)
            return
        }
        fetchLinesFromNetwork()
    }
    
    private func fetchLinesFromNetwork() {
        isLoading = true
        Task {
            do {
                async let metroData = APIService.shared.getMetroLines()
                async let busData = APIService.shared.getBusLines()
                
                let parsedMetroLines = parseLines(from: try await metroData, type: .metro)
                let parsedBusLines = parseLines(from: try await busData, type: .bus)
                
                // Cache the raw parsed data.
                CacheManager.shared.saveData(parsedMetroLines, forKey: CacheManager.metroLinesCacheKey)
                CacheManager.shared.saveData(parsedBusLines, forKey: CacheManager.busLinesCacheKey)

                await MainActor.run {
                    // Process the newly fetched data for display.
                    processAndSortLines(metro: parsedMetroLines, bus: parsedBusLines)
                    self.isLoading = false
                }
            } catch {
                print("Error loading lines: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }
    
    /// This central function ensures lines are always correctly localized and sorted.
    private func processAndSortLines(metro: [Line], bus: [Line]) {
        // 1. Re-localize Metro lines every time to match the current app language.
        let localizedMetroLines = metro.map { line -> Line in
            var mutableLine = line
            mutableLine.name = LineColorHelper.getMetroLineName(line.id)
            return mutableLine
        }
        
        // 2. Sort Metro lines alphabetically by their newly localized name.
        self.metroLines = localizedMetroLines.sorted {
            ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending
        }
        
        // 3. Sort Bus lines with a smarter numeric comparison.
        self.busLines = bus.sorted { line1, line2 in
            let name1 = line1.name ?? ""
            let name2 = line2.name ?? ""
            let isBRT1 = name1.uppercased().hasPrefix("BRT")
            let isBRT2 = name2.uppercased().hasPrefix("BRT")

            if isBRT1 != isBRT2 {
                return isBRT1 // BRT lines come before regular bus lines.
            }
            
            // For non-BRT lines, attempt a true numeric sort.
            if !isBRT1 {
                if let num1 = Int(name1), let num2 = Int(name2) {
                    return num1 < num2
                }
            }
            
            // Fallback to localized standard compare for BRT lines or mixed content.
            return name1.localizedStandardCompare(name2) == .orderedAscending
        }
        
        // 4. Combine for the "All" tab.
        self.allLines = self.metroLines + self.busLines
    }
    
    private func parseLines(from data: [String: Any], type: LineType) -> [Line] {
        guard let linesString = data["lines"] as? String else { return [] }
        let lineIDs = linesString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        // When parsing, the name is just the ID for both types initially.
        // The localization is applied later in processAndSortLines.
        return lineIDs.map { id in
            return Line(id: id, name: id, type: type.rawValue, color: nil, directions: nil, stationsByDirection: nil, routeSummary: nil)
        }
    }
    
    private enum LineType: String, Codable {
        case metro
        case bus
    }
}

// LineRow and Preview remain unchanged...
struct LineRow: View {
    let line: Line
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(line.isMetro ? LineColorHelper.getMetroLineColor(line.id) : LineColorHelper.getBusLineColor())
                .frame(width: 8)
            Circle().fill(line.isMetro ? .blue : .green).frame(width: 40, height: 40)
                .overlay(Image(systemName: line.isMetro ? "tram.fill" : "bus.fill").foregroundColor(.white).font(.system(size: 20)))
            VStack(alignment: .leading, spacing: 4) {
                Text(line.name ?? line.id).font(.headline)
                Text(line.type?.capitalized ?? "Line").font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray)
        }.padding(.vertical, 4)
    }
}

#Preview { NavigationView { LinesView() } }
