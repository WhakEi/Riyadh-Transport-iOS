//
//  LineColorHelper.swift
//  Riyadh Transport
//
//  Helper for metro line colors
//

import SwiftUI

struct LineColorHelper {
    
    static func getMetroLineColor(_ lineIdentifier: String?) -> Color {
        guard let lineIdentifier = lineIdentifier else { return .blue }
        
        let cleanIdentifier = lineIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        switch cleanIdentifier {
        case "blue line", "1": return Color(red: 0.0, green: 0.45, blue: 0.8)
        case "red line", "2": return Color(red: 0.9, green: 0.2, blue: 0.2)
        case "orange line", "3": return Color(red: 1.0, green: 0.6, blue: 0.0)
        case "yellow line", "4": return Color(red: 1.0, green: 0.8, blue: 0.0)
        case "green line", "5": return Color(red: 0.2, green: 0.7, blue: 0.3)
        case "purple line", "6": return Color(red: 0.6, green: 0.2, blue: 0.8)
        default: return .blue
        }
    }
    
    /// Takes a line identifier (e.g., "1" or "Blue Line") and returns the fully localized name.
    static func getMetroLineName(_ lineIdentifier: String?) -> String {
        guard let lineIdentifier = lineIdentifier else { return "" }
        
        let cleanIdentifier = lineIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let localizationKey: String
        switch cleanIdentifier {
        case "blue line", "1": localizationKey = "blue_line"
        case "red line", "2": localizationKey = "red_line"
        case "orange line", "3": localizationKey = "orange_line"
        case "yellow line", "4": localizationKey = "yellow_line"
        case "green line", "5": localizationKey = "green_line"
        case "purple line", "6": localizationKey = "purple_line"
        default: return lineIdentifier // Fallback to the original identifier if no match
        }
        
        return localizedString(localizationKey, comment: "Metro line name")
    }
    
    static func getBusLineColor() -> Color {
        return Color(red: 0.0, green: 0.6, blue: 0.4)
    }
    
    static func getWalkColor() -> Color {
        return .gray
    }
    
    static func getColorForSegment(type: String?, line: String?) -> Color {
        guard let type = type else { return .blue }
        
        switch type.lowercased() {
        case "walk": return getWalkColor()
        case "metro": return getMetroLineColor(line)
        case "bus": return getBusLineColor()
        default: return .blue
        }
    }
}
