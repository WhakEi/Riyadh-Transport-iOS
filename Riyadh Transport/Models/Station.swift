//
//  Station.swift
//  Riyadh Transport
//
//  Swift model for transport stations
//

import Foundation
import CoreLocation

struct Station: Codable, Identifiable {
    var id: String { value ?? name ?? label ?? UUID().uuidString }
    
    let value: String?
    let label: String?
    let name: String?
    let type: String?
    let lat: Double?
    let lng: Double?
    let distance: Double?
    let duration: Double?
    
    var latitude: Double {
        return lat ?? 0.0
    }
    
    var longitude: Double {
        return lng ?? 0.0
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var isMetro: Bool {
        return type?.lowercased() == "metro"
    }
    
    var isBus: Bool {
        return type?.lowercased() == "bus"
    }
    
    var displayName: String {
        var displayName: String?
        if let label = label {
            displayName = label
        } else if let name = name {
            displayName = name
        } else {
            displayName = value
        }
        
        // Strip (Bus) or (Metro) suffix
        if let name = displayName {
            return name
                .replacingOccurrences(of: "\\s*\\(Bus\\)\\s*$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\(Metro\\)\\s*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }
        
        return displayName ?? "Unknown Station"
    }
    
    var rawName: String {
        return label ?? name ?? value ?? ""
    }
    
    var distanceInMeters: Double {
        return distance ?? 0.0
    }
    
    var durationInSeconds: Double {
        return duration ?? 0.0
    }
}
