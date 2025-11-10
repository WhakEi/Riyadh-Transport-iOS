//
//  JourneyUpdateManager.swift
//  Riyadh Transport
//
//  Core logic for calculating real-time journey updates
//

import Foundation

class JourneyUpdateManager {
    static let shared = JourneyUpdateManager()
    private let liveArrivalService = LiveArrivalService.shared
    private let maxWaitMinutes = 45
    
    private init() {}
    
    /// Update route with live arrival data
    /// - Parameter route: The route to update
    /// - Returns: Updated route with live data and new total time
    func updateRouteWithLiveData(_ route: Route) async throws -> (route: Route, newTotalMinutes: Int) {
        var updatedSegments: [RouteSegment] = []
        var cumulativeTravelTime: Double = 0.0  // Total time spent on travel (walking + riding)
        var newTotalJourneyTime: Double = 0.0  // New total time including wait times
        var connectionMissed = false
        
        print("\n\n--- [JUM] Starting Live Route Update at \(Date()) ---")

        for (index, segment) in route.segments.enumerated() {
            var updatedSegment = segment
            
            let segmentRideMinutes = segment.durationInSeconds / 60.0
            
            if segment.isWalking {
                cumulativeTravelTime += segmentRideMinutes
                newTotalJourneyTime += segmentRideMinutes
                updatedSegment.arrivalStatus = nil
                updatedSegment.waitMinutes = nil
                updatedSegments.append(updatedSegment)
                continue
            }
            
            if segment.isBus || segment.isMetro {
                if connectionMissed {
                    cumulativeTravelTime += segmentRideMinutes
                    newTotalJourneyTime += segmentRideMinutes
                    updatedSegment.arrivalStatus = "hidden"
                    updatedSegment.waitMinutes = nil
                    updatedSegments.append(updatedSegment)
                    continue
                }
                
                updatedSegment.arrivalStatus = "checking"
                
                guard let startStation = segment.stations?.first else {
                    cumulativeTravelTime += segmentRideMinutes
                    newTotalJourneyTime += segmentRideMinutes
                    updatedSegment.arrivalStatus = "hidden"
                    updatedSegments.append(updatedSegment)
                    continue
                }
                
                print("\n--- [JUM] Processing Segment \(index + 1): \(segment.type?.uppercased() ?? "") from '\(startStation)' ---")

                do {
                    // --- Resolve the definitive terminus BEFORE fetching live data ---
                    if let resolvedTerminus = await TerminusResolver.shared.resolveTerminus(for: updatedSegment) {
                        print("--- [JUM] TerminusResolver SUCCESS: For line \(updatedSegment.line ?? "N/A"), resolved terminus to '\(resolvedTerminus)'")
                        updatedSegment.refinedTerminus = resolvedTerminus
                    } else {
                        print("--- [JUM] TerminusResolver FAILED: Could not resolve terminus for line \(updatedSegment.line ?? "N/A").")
                    }
                    
                    let segmentType = segment.isMetro ? "metro" : "bus"
                    let liveData = try await liveArrivalService.fetchLiveArrivals(
                        stationName: startStation,
                        type: segmentType
                    )
                    
                    print("--- [JUM] Raw network response for '\(startStation)':")
                    dump(liveData.arrivals)
                    
                    let validArrival = findValidArrival(
                        arrivals: liveData.arrivals,
                        segment: updatedSegment,
                        cumulativeTravelTime: cumulativeTravelTime
                    )
                    
                    if let arrival = validArrival {
                        let waitMinutes = Double(arrival.minutesUntil) - cumulativeTravelTime
                        
                        if waitMinutes > Double(maxWaitMinutes) {
                            connectionMissed = true
                            cumulativeTravelTime += segmentRideMinutes
                            newTotalJourneyTime += segmentRideMinutes
                            updatedSegment.arrivalStatus = "hidden"
                            updatedSegment.waitMinutes = nil
                            print("--- [JUM] Result: Connection MISSED (wait time \(waitMinutes) > \(maxWaitMinutes) mins).")
                        } else {
                            newTotalJourneyTime += waitMinutes + segmentRideMinutes
                            cumulativeTravelTime += segmentRideMinutes
                            updatedSegment.waitMinutes = Int(ceil(waitMinutes))
                            updatedSegment.nextArrivalMinutes = arrival.minutesUntil
                            updatedSegment.refinedTerminus = arrival.destination
                            updatedSegment.arrivalStatus = arrival.minutesUntil >= 59 ? "normal" : "live"
                            updatedSegment.upcomingArrivals = getUpcomingArrivals(
                                arrivals: liveData.arrivals,
                                currentArrival: arrival
                            )
                            print("--- [JUM] Result: Match FOUND. Final status: '\(updatedSegment.arrivalStatus ?? "nil")', Next Arrival: \(updatedSegment.nextArrivalMinutes ?? -1) mins.")
                        }
                    } else {
                        connectionMissed = true
                        cumulativeTravelTime += segmentRideMinutes
                        newTotalJourneyTime += segmentRideMinutes
                        updatedSegment.arrivalStatus = "hidden"
                        updatedSegment.waitMinutes = nil
                        print("--- [JUM] Result: NO MATCH FOUND.")
                    }
                } catch {
                    print("--- [JUM] Result: Network/Decoding ERROR. \(error.localizedDescription)")
                    cumulativeTravelTime += segmentRideMinutes
                    newTotalJourneyTime += segmentRideMinutes
                    updatedSegment.arrivalStatus = "hidden"
                    updatedSegment.waitMinutes = nil
                }
                
                updatedSegments.append(updatedSegment)
            }
        }
        
        let updatedRoute = Route(
            segments: updatedSegments,
            totalTime: newTotalJourneyTime * 60.0
        )
        
        print("\n--- [JUM] Live Route Update Finished ---\n")
        return (updatedRoute, Int(ceil(newTotalJourneyTime)))
    }
    
    // MARK - Helper Methods
    
    private func findValidArrival(
        arrivals: [LiveArrival],
        segment: RouteSegment,
        cumulativeTravelTime: Double
    ) -> LiveArrival? {
        guard let canonicalSegmentLine = LineColorHelper.getCanonicalLineIdentifier(segment.line) else { return nil }

        let normalizedSegmentTerminus = segment.refinedTerminus?.strippedStationSuffix().lowercased()
        let lastStation = segment.stations?.last
        let normalizedLastStation = lastStation?.strippedStationSuffix().lowercased()

        print("--- [JUM] -> findValidArrival called:")
        print("---      SEGMENT to match: Line '\(segment.line ?? "nil")' (Canonical: '\(canonicalSegmentLine)'), Terminus: '\(normalizedSegmentTerminus ?? "nil")', Last Station: '\(normalizedLastStation ?? "nil")'")

        let matchingArrivals = arrivals.filter { arrival in
            let canonicalArrivalLine = LineColorHelper.getCanonicalLineIdentifier(arrival.line)
            guard canonicalArrivalLine == canonicalSegmentLine else { return false }
            guard Double(arrival.minutesUntil) >= cumulativeTravelTime else { return false }

            let normalizedArrivalDest = arrival.destination.strippedStationSuffix().lowercased()
            
            if let terminus = normalizedSegmentTerminus, !terminus.isEmpty {
                if normalizedArrivalDest.contains(terminus) || terminus.contains(normalizedArrivalDest) {
                    return true
                }
            }
            if let station = normalizedLastStation, !station.isEmpty {
                 if normalizedArrivalDest.contains(station) || station.contains(normalizedArrivalDest) {
                    return true
                }
            }
            return false
        }
        
        let result = matchingArrivals.sorted(by: { $0.minutesUntil < $1.minutesUntil }).first
        
        if let match = result {
             print("--- [JUM] -> findValidArrival: EARLIEST MATCH is line '\(match.line)' to '\(match.destination)' in \(match.minutesUntil) mins.")
        } else {
             print("--- [JUM] -> findValidArrival: NO MATCHING ARRIVAL FOUND.")
        }
        return result
    }
    
    private func getUpcomingArrivals(
        arrivals: [LiveArrival],
        currentArrival: LiveArrival
    ) -> [Int] {
        guard let canonicalTargetLine = LineColorHelper.getCanonicalLineIdentifier(currentArrival.line) else { return [] }
        let normalizedTargetDestination = currentArrival.destination.strippedStationSuffix().lowercased()
        
        let upcomingArrivals = arrivals.filter { arrival in
            guard let canonicalArrivalLine = LineColorHelper.getCanonicalLineIdentifier(arrival.line),
                  canonicalArrivalLine == canonicalTargetLine else { return false }
            guard arrival.minutesUntil > currentArrival.minutesUntil else { return false }
            let normalizedArrivalDest = arrival.destination.strippedStationSuffix().lowercased()
            return normalizedArrivalDest.contains(normalizedTargetDestination) ||
                   normalizedTargetDestination.contains(normalizedArrivalDest)
        }
        
        let sorted = upcomingArrivals.sorted(by: { $0.minutesUntil < $1.minutesUntil })
        return Array(sorted.prefix(3).map { $0.minutesUntil })
    }
}
