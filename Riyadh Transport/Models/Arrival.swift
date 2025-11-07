//
//  Arrival.swift
//  Riyadh Transport
//
//  Swift model for arrival times
//

import Foundation

struct Arrival: Codable, Identifiable {
    var id: String { UUID().uuidString }
    
    let line: String?
    let destination: String?
    let minutesUntil: Int?
    
    enum CodingKeys: String, CodingKey {
        case line
        case destination
        case minutesUntil = "minutes_until"
    }
}
