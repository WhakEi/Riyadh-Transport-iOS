//
//  Line.swift
//  Riyadh Transport
//
//  Swift model for transport lines
//

import Foundation

struct Line: Codable, Identifiable, Hashable {
    var id: String
    var name: String?
    let type: String?
    let color: String?
    let directions: [String]?
    
    // This will now be populated by our eager-loading process.
    var stationsByDirection: [String: [String]]?
    
    // The route summary will be generated from the station data.
    var routeSummary: String?
    
    var isMetro: Bool {
        return type?.lowercased() == "metro"
    }
    
    var isBus: Bool {
        return type?.lowercased() == "bus"
    }
    
    // Conform to Hashable for modern NavigationLinks
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Line, rhs: Line) -> Bool {
        lhs.id == rhs.id
    }
}
