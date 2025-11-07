//
//  Line.swift
//  Riyadh Transport
//
//  Swift model for transport lines
//

import Foundation

struct Line: Codable, Identifiable {
    var id: String
    let name: String?
    let type: String?
    let color: String?
    let directions: [String]?
    let stationsByDirection: [String: [String]]?
    let routeSummary: String?
    
    // Live arrival data (not serialized, runtime only)
    var upcomingArrivals: [Int]?
    var arrivalStatus: String? // "checking", "live", "hidden", "normal"
    var destination: String?
    
    var isMetro: Bool {
        return type?.lowercased() == "metro"
    }
    
    var isBus: Bool {
        return type?.lowercased() == "bus"
    }
}
