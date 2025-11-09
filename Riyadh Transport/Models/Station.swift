//
//  Station.swift
//  Riyadh Transport
//
//  Swift model for transport stations
//

import Foundation
import CoreLocation

struct Station: Codable, Identifiable, Hashable {
    let rawName: String
    let lat: Double
    let lng: Double
    let type: String?
    let distance: Double?
    let duration: Double?
    
    var id: String { rawName }
    
    var displayName: String {
        return rawName
            .replacingOccurrences(of: "\\s*\\(Bus\\)\\s*$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s*\\(Metro\\)\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    var latitude: Double { lat }
    var longitude: Double { lng }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isMetro: Bool {
        return type?.lowercased() == "metro"
    }
    
    var isBus: Bool {
        return type?.lowercased() == "bus"
    }
    
    var distanceInMeters: Double {
        return distance ?? 0.0
    }
    
    var durationInSeconds: Double {
        return duration ?? 0.0
    }
    
    // Define all possible keys from all relevant API endpoints.
    private enum CodingKeys: String, CodingKey {
        case label, value, name, type, distance, duration
        // Add all possible keys for coordinates
        case lat, lng, latitude, longitude
        case rawName // Internal use, not from API
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Find the raw name from the first available key.
        if let label = try? container.decode(String.self, forKey: .label) {
            self.rawName = label
        } else if let value = try? container.decode(String.self, forKey: .value) {
            self.rawName = value
        } else if let name = try? container.decode(String.self, forKey: .name) {
            self.rawName = name
        } else {
            throw DecodingError.dataCorruptedError(forKey: .rawName, in: container, debugDescription: "Station name not found")
        }
        
        // --- NEW: More flexible coordinate decoding ---
        func decodeCoordinate(primaryKey: CodingKeys, fallbackKey: CodingKeys) -> Double {
            // Try primary key as Double, then as a String that can be converted.
            if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: primaryKey) { return doubleVal ?? 0.0 }
            if let stringVal = try? container.decodeIfPresent(String.self, forKey: primaryKey), let doubleVal = Double(stringVal) { return doubleVal }
            
            // If primary key fails, try the fallback key as Double, then as a String.
            if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: fallbackKey) { return doubleVal ?? 0.0 }
            if let stringVal = try? container.decodeIfPresent(String.self, forKey: fallbackKey), let doubleVal = Double(stringVal) { return doubleVal }
            
            return 0.0 // Default to 0.0 if neither key is found or valid.
        }
        
        // Use the helper to check for "lat" or "latitude", and "lng" or "longitude".
        self.lat = decodeCoordinate(primaryKey: .lat, fallbackKey: .latitude)
        self.lng = decodeCoordinate(primaryKey: .lng, fallbackKey: .longitude)

        if self.lat == 0.0 && self.lng == 0.0 {
            print("WARNING: Station decoded as 0,0: \(self.rawName)")
        }
        // ------------------------------------------

        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawName, forKey: .label)
        try container.encode(lat, forKey: .lat)
        try container.encode(lng, forKey: .lng)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encodeIfPresent(duration, forKey: .duration)
    }
    
    // Initializers for previews and testing remain the same.
    init(rawName: String, type: String?, lat: Double, lng: Double) {
        self.rawName = rawName
        self.type = type
        self.lat = lat
        self.lng = lng
        self.distance = nil
        self.duration = nil
    }
    
    init(rawName: String, type: String?, lat: Double, lng: Double, distance: Double?, duration: Double?) {
        self.rawName = rawName
        self.type = type
        self.lat = lat
        self.lng = lng
        self.distance = distance
        self.duration = duration
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Station, rhs: Station) -> Bool {
        lhs.id == rhs.id
    }
}
