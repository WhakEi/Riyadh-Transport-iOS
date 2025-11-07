//
//  RouteSegment.swift
//  Riyadh Transport
//
//  Swift model for route segments
//

import Foundation

struct RouteSegment: Codable, Identifiable {
    var id: String { UUID().uuidString }
    
    let type: String?
    let line: String?
    let stations: [String]?
    let duration: Double?
    let distance: Double?
    let from: AnyCodable?
    let to: AnyCodable?
    
    // Live arrival data (not serialized, runtime only)
    var waitMinutes: Int?
    var arrivalStatus: String? // "checking", "live", "hidden", "normal"
    var refinedTerminus: String?
    var nextArrivalMinutes: Int?
    var upcomingArrivals: [Int]?
    
    var isWalking: Bool {
        return type?.lowercased() == "walk"
    }
    
    var isMetro: Bool {
        return type?.lowercased() == "metro"
    }
    
    var isBus: Bool {
        return type?.lowercased() == "bus"
    }
    
    var stopCount: Int {
        return stations?.count ?? 0
    }
    
    var durationInSeconds: Double {
        return duration ?? 0.0
    }
    
    var distanceInMeters: Double {
        return distance ?? 0.0
    }
}

// Helper to decode unknown JSON types
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
