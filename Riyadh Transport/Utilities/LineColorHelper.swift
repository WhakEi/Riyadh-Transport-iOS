//
//  LineColorHelper.swift
//  Riyadh Transport
//
//  Helper for metro line colors
//

import SwiftUI

struct LineColorHelper {
    
    static func getMetroLineColor(_ lineNumber: String?) -> Color {
        guard let lineNumber = lineNumber else {
            return .blue
        }
        
        // Clean up line number
        var cleanLine = lineNumber.trimmingCharacters(in: .whitespaces)
        if cleanLine.hasPrefix("Line ") {
            cleanLine = String(cleanLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        
        // Check for color names (English and Arabic)
        switch cleanLine.lowercased() {
        case "blue line", "1", "المسار الأزرق":
            return Color(red: 0.0, green: 0.45, blue: 0.8) // Blue
        case "red line", "2", "المسار الأحمر":
            return Color(red: 0.9, green: 0.2, blue: 0.2) // Red
        case "orange line", "3", "المسار البرتقالي":
            return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        case "yellow line", "4", "المسار الأصفر":
            return Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
        case "green line", "5", "المسار الأخضر":
            return Color(red: 0.2, green: 0.7, blue: 0.3) // Green
        case "purple line", "6", "المسار البنفسجي":
            return Color(red: 0.6, green: 0.2, blue: 0.8) // Purple
        default:
            return .blue
        }
    }
    
    static func getMetroLineName(_ lineNumber: String?) -> String {
        guard let lineNumber = lineNumber else {
            return ""
        }
        
        // Clean up line number
        var cleanLine = lineNumber.trimmingCharacters(in: .whitespaces)
        if cleanLine.hasPrefix("Line ") {
            cleanLine = String(cleanLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        }
        
        // Map to localized names
        switch cleanLine.lowercased() {
        case "blue line", "1", "المسار الأزرق":
            return NSLocalizedString("blue_line", comment: "Blue Line")
        case "red line", "2", "المسار الأحمر":
            return NSLocalizedString("red_line", comment: "Red Line")
        case "orange line", "3", "المسار البرتقالي":
            return NSLocalizedString("orange_line", comment: "Orange Line")
        case "yellow line", "4", "المسار الأصفر":
            return NSLocalizedString("yellow_line", comment: "Yellow Line")
        case "green line", "5", "المسار الأخضر":
            return NSLocalizedString("green_line", comment: "Green Line")
        case "purple line", "6", "المسار البنفسجي":
            return NSLocalizedString("purple_line", comment: "Purple Line")
        default:
            return cleanLine
        }
    }
    
    static func getBusLineColor() -> Color {
        return Color(red: 0.0, green: 0.6, blue: 0.4) // Teal for bus
    }
    
    static func getWalkColor() -> Color {
        return .gray
    }
    
    static func getColorForSegment(type: String?, line: String?) -> Color {
        guard let type = type else { return .blue }
        
        switch type.lowercased() {
        case "walk":
            return getWalkColor()
        case "metro":
            return getMetroLineColor(line)
        case "bus":
            return getBusLineColor()
        default:
            return .blue
        }
    }
}
