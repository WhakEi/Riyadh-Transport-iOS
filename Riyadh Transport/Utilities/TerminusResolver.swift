//
//  TerminusResolver.swift
//  Riyadh Transport
//
//  New service to determine the correct terminus for a given route segment
//  based on the full station list for that line.
//

import Foundation

class TerminusResolver {
    static let shared = TerminusResolver()
    
    // A simple in-memory cache to avoid re-fetching station lists for the same line.
    private var lineCache: [String: Line] = [:]
    
    private init() {}
    
    /// Fetches the full line details if not cached, then determines the correct terminus for a given route segment.
    func resolveTerminus(for segment: RouteSegment) async -> String? {
        guard let lineId = LineColorHelper.getCanonicalLineIdentifier(segment.line) else { return nil }
        
        print("--- [TR] Attempting to resolve terminus for Line \(lineId)")
        
        do {
            // Step 1: Get the full Line object with station data, from cache or network.
            let line = try await getLineDetails(lineId: lineId, isMetro: segment.isMetro)
            
            // Step 2: Apply the correct logic based on transit type.
            if segment.isMetro {
                return determineMetroTerminus(for: segment, on: line)
            } else if segment.isBus {
                return determineBusTerminus(for: segment, on: line)
            }
            
        } catch {
            print("--- [TR] Failed to resolve terminus for line \(lineId). Error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Retrieves a Line object from the cache or fetches it from the network.
    private func getLineDetails(lineId: String, isMetro: Bool) async throws -> Line {
        if let cachedLine = lineCache[lineId] {
            print("--- [TR] Cache HIT for line \(lineId).")
            return cachedLine
        }
        
        print("--- [TR] Cache MISS for line \(lineId). Fetching from network...")
        var line = Line(id: lineId, name: lineId, type: isMetro ? "metro" : "bus", color: nil, directions: nil, stationsByDirection: nil, routeSummary: nil)
        
        if isMetro {
            let stations = try await APIService.shared.getMetroStations(forLine: lineId)
            line.stationsByDirection = ["main": stations]
        } else {
            let stationsByDirection = try await APIService.shared.getBusStations(forLine: lineId)
            line.stationsByDirection = stationsByDirection
        }
        
        lineCache[lineId] = line
        print("--- [TR] Fetched and cached line \(lineId).")
        return line
    }
    
    /// Determines the terminus for a metro line based on station order.
    private func determineMetroTerminus(for segment: RouteSegment, on line: Line) -> String? {
        guard let stations = line.stationsByDirection?["main"],
              let startStationName = segment.stations?.first,
              let endStationName = segment.stations?.last else {
            print("--- [TR] Metro: Missing station data for segment.")
            return nil
        }
        
        // --- NEW: Log the full station list for debugging ---
        print("--- [TR] Metro: Full station list for Line \(line.id):")
        dump(stations)
        
        let normalizedStart = startStationName.strippedStationSuffix()
        let normalizedEnd = endStationName.strippedStationSuffix()
        
        // --- FIX: Perform a case-insensitive comparison to handle mismatches like "Kafd" vs "KAFD" ---
        guard let startIndex = stations.firstIndex(where: { $0.strippedStationSuffix().lowercased() == normalizedStart.lowercased() }),
              let endIndex = stations.firstIndex(where: { $0.strippedStationSuffix().lowercased() == normalizedEnd.lowercased() }) else {
            print("--- [TR] Metro: Could not find start ('\(normalizedStart)') or end ('\(normalizedEnd)') station in list for line \(line.id)")
            return nil
        }
        
        print("--- [TR] Metro: Found start '\(normalizedStart)' at index \(startIndex), end '\(normalizedEnd)' at index \(endIndex).")
        
        if startIndex > endIndex {
            let terminus = stations.first
            print("--- [TR] Metro: Direction is upwards. Terminus: '\(terminus ?? "N/A")'")
            return terminus
        } else if startIndex < endIndex {
            let terminus = stations.last
            print("--- [TR] Metro: Direction is downwards. Terminus: '\(terminus ?? "N/A")'")
            return terminus
        }
        
        print("--- [TR] Metro: Start and end index are the same. Cannot determine direction.")
        return nil
    }
    
    /// Determines the terminus for a bus line by finding which direction contains the destination station.
    private func determineBusTerminus(for segment: RouteSegment, on line: Line) -> String? {
        guard let stationsByDirection = line.stationsByDirection,
              let endStationName = segment.stations?.last else {
            print("--- [TR] Bus: Missing station data for segment.")
            return nil
        }
        
        let normalizedEnd = endStationName.strippedStationSuffix()
        
        for (direction, stations) in stationsByDirection {
            // --- FIX: Perform a case-insensitive comparison ---
            if stations.contains(where: { $0.strippedStationSuffix().lowercased() == normalizedEnd.lowercased() }) {
                print("--- [TR] Bus: Found end station '\(normalizedEnd)' in direction '\(direction)'. Terminus: '\(direction)'")
                return direction
            }
        }
        
        print("--- [TR] Bus: Could not find end station '\(normalizedEnd)' in any direction for line \(line.id)")
        return nil
    }
}
