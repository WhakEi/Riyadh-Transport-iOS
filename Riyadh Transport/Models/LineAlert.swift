//
//  LineAlert.swift
//  Riyadh Transport
//
//  Model for Line Alerts from AppWrite
//

import Foundation

struct LineAlert: Codable, Identifiable {
    let id: String
    let title: String
    let message: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case title
        case message
        case createdAt = "$createdAt"
    }
    
    /// Extracts the line number from title if it starts with [number]
    /// Returns nil if no line number is found (meaning it's a general alert)
    var affectedLineNumber: String? {
        // Match pattern: [123] or [3] or [150]
        let pattern = "^\\[(\\d+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: title, options: [], range: NSRange(title.startIndex..., in: title)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: title) else {
            return nil
        }
        return String(title[range])
    }
    
    /// Returns the title without the [number] prefix
    var displayTitle: String {
        let pattern = "^\\[\\d+\\]\\s*"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return title
        }
        let range = NSRange(title.startIndex..., in: title)
        return regex.stringByReplacingMatches(in: title, options: [], range: range, withTemplate: "")
    }
    
    /// Returns true if this is a general alert (no line number in title)
    var isGeneralAlert: Bool {
        return affectedLineNumber == nil
    }
    
    /// Returns true if this alert should be expanded by default
    var shouldExpandByDefault: Bool {
        return !isGeneralAlert
    }
}

struct LineAlertsResponse: Codable {
    let documents: [LineAlert]
}
