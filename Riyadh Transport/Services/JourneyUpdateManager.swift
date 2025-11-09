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
        
        for (index, segment) in route.segments.enumerated() {
            var updatedSegment = segment
            
            // Calculate segment ride time in minutes
            let segmentRideMinutes = segment.durationInSeconds / 60.0
            
            // Handle walk segments
            if segment.isWalking {
                // Add to both counters
                cumulativeTravelTime += segmentRideMinutes
                newTotalJourneyTime += segmentRideMinutes
                
                updatedSegment.arrivalStatus = nil
                updatedSegment.waitMinutes = nil
                updatedSegments.append(updatedSegment)
                continue
            }
            
            // Handle bus/metro segments
            if segment.isBus || segment.isMetro {
                // If already missed a connection, all future segments are static
                if connectionMissed {
                    cumulativeTravelTime += segmentRideMinutes
                    newTotalJourneyTime += segmentRideMinutes
                    updatedSegment.arrivalStatus = "hidden"
                    updatedSegment.waitMinutes = nil
                    updatedSegments.append(updatedSegment)
                    continue
                }
                
                // Mark segment as checking while we fetch data
                updatedSegment.arrivalStatus = "checking"
                
                // Query live data
                guard let startStation = segment.stations?.first else {
                    // No station info, treat as static
                    cumulativeTravelTime += segmentRideMinutes
                    newTotalJourneyTime += segmentRideMinutes
                    updatedSegment.arrivalStatus = "hidden"
                    updatedSegments.append(updatedSegment)
                    continue
                }
                
                do {
                    let segmentType = segment.isMetro ? "metro" : "bus"
                    let liveData = try await liveArrivalService.fetchLiveArrivals(
                        stationName: startStation,
                        type: segmentType
                    )
                    
                    // Find valid arrival
                    let validArrival = findValidArrival(
                        arrivals: liveData.arrivals,
                        segment: segment,
                        cumulativeTravelTime: cumulativeTravelTime
                    )
                    
                    if let arrival = validArrival {
                        let waitMinutes = Double(arrival.minutesUntil) - cumulativeTravelTime
                        
                        // Check if wait is too long
                        if waitMinutes > Double(maxWaitMinutes) {
                            // Treat as missed connection
                            connectionMissed = true
                            cumulativeTravelTime += segmentRideMinutes
                            newTotalJourneyTime += segmentRideMinutes
                            updatedSegment.arrivalStatus = "hidden"
                            updatedSegment.waitMinutes = nil
                        } else {
                            // Valid arrival found with acceptable wait time
                            newTotalJourneyTime += waitMinutes + segmentRideMinutes
                            cumulativeTravelTime += segmentRideMinutes
                            
                            updatedSegment.waitMinutes = Int(ceil(waitMinutes))
                            updatedSegment.nextArrivalMinutes = arrival.minutesUntil
                            updatedSegment.refinedTerminus = arrival.destination
                            
                            // Determine display status
                            if arrival.minutesUntil >= 59 {
                                updatedSegment.arrivalStatus = "normal"
                            } else {
                                updatedSegment.arrivalStatus = "live"
                            }
                            
                            // Get upcoming arrivals (next 2-3 arrivals)
                            updatedSegment.upcomingArrivals = getUpcomingArrivals(
                                arrivals: liveData.arrivals,
                                segment: segment,
                                currentArrival: arrival
                            )
                        }
                    } else {
                        // No valid arrival found - missed connection
                        connectionMissed = true
                        cumulativeTravelTime += segmentRideMinutes
                        newTotalJourneyTime += segmentRideMinutes
                        updatedSegment.arrivalStatus = "hidden"
                        updatedSegment.waitMinutes = nil
                    }
                } catch {
                    // API error - treat as static
                    print("Error fetching live data for \(startStation): \(error)")
                    cumulativeTravelTime += segmentRideMinutes
                    newTotalJourneyTime += segmentRideMinutes
                    updatedSegment.arrivalStatus = "hidden"
                    updatedSegment.waitMinutes = nil
                }
                
                updatedSegments.append(updatedSegment)
            }
        }
        
        // Create updated route
        let updatedRoute = Route(
            segments: updatedSegments,
            totalTime: newTotalJourneyTime * 60.0  // Convert back to seconds
        )
        
        return (updatedRoute, Int(ceil(newTotalJourneyTime)))
    }
    
    // MARK: - Helper Methods
    
    /// Find the next valid arrival for a segment
    private func findValidArrival(
        arrivals: [LiveArrival],
        segment: RouteSegment,
        cumulativeTravelTime: Double
    ) -> LiveArrival? {
        guard let segmentLine = segment.line,
              let lastStation = segment.stations?.last else {
            return nil
        }
        
        // Filter arrivals that match the line and destination
        let matchingArrivals = arrivals.filter { arrival in
            // Match line
            let lineMatches = arrival.line == segmentLine
            
            // Match destination (last station of segment)
            let destinationMatches = arrival.destination.contains(lastStation) ||
                                   lastStation.contains(arrival.destination)
            
            // Check if not already departed (has enough time to reach)
            let notDeparted = Double(arrival.minutesUntil) >= cumulativeTravelTime
            
            return lineMatches && destinationMatches && notDeparted
        }
        
        // Return the earliest matching arrival
        return matchingArrivals.sorted(by: { $0.minutesUntil < $1.minutesUntil }).first
    }
    
    /// Get upcoming arrivals after the current one
    private func getUpcomingArrivals(
        arrivals: [LiveArrival],
        segment: RouteSegment,
        currentArrival: LiveArrival
    ) -> [Int] {
        guard let segmentLine = segment.line,
              let lastStation = segment.stations?.last else {
            return []
        }
        
        // Filter arrivals that match and are after current
        let upcomingArrivals = arrivals.filter { arrival in
            let lineMatches = arrival.line == segmentLine
            let destinationMatches = arrival.destination.contains(lastStation) ||
                                   lastStation.contains(arrival.destination)
            let isAfter = arrival.minutesUntil > currentArrival.minutesUntil
            
            return lineMatches && destinationMatches && isAfter
        }
        
        // Sort by time and take first 2-3
        let sorted = upcomingArrivals.sorted(by: { $0.minutesUntil < $1.minutesUntil })
        return Array(sorted.prefix(3).map { $0.minutesUntil })
    }
}
