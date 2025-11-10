//
//  LineStationLoader.swift
//  Riyadh Transport
//

import Foundation
import Combine

@MainActor
class LineStationLoader: ObservableObject {
    @Published var lines: [Line] = []
    @Published var isLoadingList = false
    
    private var stationFetchTask: Task<Void, Never>?

    private let metroLinesCacheKey = "cachedCompleteMetroLines"
    private let busLinesCacheKey = "cachedCompleteBusLines"

    func loadLineList() {
        guard lines.isEmpty else { return }

        if let cachedMetro: [Line] = CacheManager.shared.loadData(forKey: metroLinesCacheKey, maxAgeInDays: 7),
           let cachedBus: [Line] = CacheManager.shared.loadData(forKey: busLinesCacheKey, maxAgeInDays: 7) {
            processAndSortLines(metro: cachedMetro, bus: cachedBus)
            return
        }
        
        fetchAndCacheAllLineData()
    }
    
    private func fetchAndCacheAllLineData() {
        isLoadingList = true
        stationFetchTask?.cancel()
        
        stationFetchTask = Task {
            do {
                async let metroData = APIService.shared.getMetroLines()
                async let busData = APIService.shared.getBusLines()
                
                let initialMetroLines = parseLines(from: try await metroData, type: .metro)
                let initialBusLines = parseLines(from: try await busData, type: .bus)
                
                async let completeMetroLines = fetchStationsForAll(lines: initialMetroLines)
                async let completeBusLines = fetchStationsForAll(lines: initialBusLines)
                
                let finalMetroLines = try await completeMetroLines
                let finalBusLines = try await completeBusLines
                
                CacheManager.shared.saveData(finalMetroLines, forKey: metroLinesCacheKey)
                CacheManager.shared.saveData(finalBusLines, forKey: busLinesCacheKey)

                processAndSortLines(metro: finalMetroLines, bus: finalBusLines)
                isLoadingList = false
                
            } catch {
                print("Error fetching and caching all line data: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                isLoadingList = false
            }
        }
    }
    
    private func fetchStationsForAll(lines: [Line]) async throws -> [Line] {
        try await withThrowingTaskGroup(of: Line.self) { group in
            var completeLines = [Line]()
            completeLines.reserveCapacity(lines.count)
            
            for line in lines {
                group.addTask {
                    var updatedLine = line
                    // **THE FIX**: Make a local, non-isolated copy of the property before using it in the task.
                    let isMetro = line.isMetro
                    if isMetro {
                        let stations = try await APIService.shared.getMetroStations(forLine: line.id)
                        updatedLine.stationsByDirection = ["main": stations]
                    } else {
                        updatedLine.stationsByDirection = try await APIService.shared.getBusStations(forLine: line.id)
                    }
                    return updatedLine
                }
            }
            
            for try await completeLine in group {
                completeLines.append(completeLine)
            }
            
            return completeLines
        }
    }
    
    private func generateRouteSummary(for line: Line) -> String {
        guard let stationData = line.stationsByDirection else { return "" }
        
        if line.isMetro {
            let stations = stationData["main"] ?? []
            return "\(stations.first ?? "") - \(stations.last ?? "")"
        } else {
            let directions = stationData.keys.sorted()
            if directions.count == 1, let directionName = directions.first {
                let format = localizedString("ring_route_format")
                return String(format: format, directionName)
            } else {
                return directions.joined(separator: " - ")
            }
        }
    }
    
    private func processAndSortLines(metro: [Line], bus: [Line]) {
        var completeMetro = metro
        var completeBus = bus

        // **THE FIX**: Generate summaries here on the MainActor, after all data is fetched.
        for i in completeMetro.indices {
            completeMetro[i].routeSummary = generateRouteSummary(for: completeMetro[i])
        }
        for i in completeBus.indices {
            completeBus[i].routeSummary = generateRouteSummary(for: completeBus[i])
        }

        let localizedMetroLines = completeMetro.map { line -> Line in
            var mutableLine = line
            mutableLine.name = LineColorHelper.getMetroLineName(line.id)
            return mutableLine
        }
        let sortedMetro = localizedMetroLines.sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
        let sortedBuses = completeBus.sorted { l1, l2 in
            let n1 = l1.name ?? ""; let n2 = l2.name ?? ""
            let isBRT1 = n1.uppercased().hasPrefix("BRT"); let isBRT2 = n2.uppercased().hasPrefix("BRT")
            if isBRT1 != isBRT2 { return isBRT1 }
            if !isBRT1 { if let num1 = Int(n1), let num2 = Int(n2) { return num1 < num2 } }
            return n1.localizedStandardCompare(n2) == .orderedAscending
        }
        self.lines = sortedMetro + sortedBuses
    }
    
    private func parseLines(from data: [String: Any], type: LineType) -> [Line] {
        guard let linesString = data["lines"] as? String else { return [] }
        let lineIDs = linesString.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        return lineIDs.map { id in Line(id: id, name: id, type: type.rawValue, color: nil, directions: nil, stationsByDirection: nil, routeSummary: nil) }
    }
    
    private enum LineType: String, Codable { case metro, bus }
}
