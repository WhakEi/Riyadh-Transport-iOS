//
//  Route.swift
//  Riyadh Transport
//
//  Swift model for transport routes
//

import Foundation

struct Route: Codable, Equatable {
    let segments: [RouteSegment]
    let totalTime: Double
    
    enum CodingKeys: String, CodingKey {
        case segments
        case totalTime = "total_time"
    }
    
    var totalMinutes: Int {
        return Int(ceil(totalTime / 60.0))
    }
}
