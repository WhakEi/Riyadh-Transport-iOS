//
//  SearchResult.swift
//  Riyadh Transport
//
//  Swift model for search results
//

import Foundation
import CoreLocation

// Make the struct Codable and Hashable for easier persistence and use in collections.
struct SearchResult: Identifiable, Codable, Hashable {
    // A stable ID is crucial for SwiftUI's List to work correctly.
    // We use the station's original ID if it's a station, otherwise
    // we create a stable ID by combining the properties that make a result unique.
    var id: String {
        return stationId ?? "\(name)-\(latitude)-\(longitude)"
    }

    let name: String
    let latitude: Double
    let longitude: Double
    let type: SearchResultType
    
    // Add an optional stationID to hold the original, stable ID from the Station model.
    let stationId: String?
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Custom initializer to allow creating results without a stationId.
    init(name: String, latitude: Double, longitude: Double, type: SearchResultType, stationId: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.stationId = stationId
    }

    // Add an explicit Equatable conformance to simplify checking for existence in arrays.
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Make the enum Codable to allow SearchResult to be encoded/decoded.
enum SearchResultType: String, Codable {
    case station
    case location
    case recent
}
