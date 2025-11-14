//
//  LineAlertService.swift
//  Riyadh Transport
//
//  Service for managing and filtering line alerts
//

import Foundation

class LineAlertService {
    static let shared = LineAlertService()
    
    private var cachedAlerts: [LineAlert] = []
    private var lastFetchTime: Date?
    private let cacheValidityInterval: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    /// Fetches alerts from AppWrite, using cache if available and valid
    func fetchAlerts(forceRefresh: Bool = false) async throws -> [LineAlert] {
        // Check if cache is valid
        if !forceRefresh,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheValidityInterval,
           !cachedAlerts.isEmpty {
            return cachedAlerts
        }
        
        // Fetch fresh alerts
        let alerts = try await AppWriteService.shared.fetchLineAlerts()
        cachedAlerts = alerts
        lastFetchTime = Date()
        return alerts
    }
    
    /// Returns general alerts (no line number in title)
    func getGeneralAlerts() async throws -> [LineAlert] {
        let alerts = try await fetchAlerts()
        return alerts.filter { $0.isGeneralAlert }
    }
    
    /// Returns alerts for a specific line number
    func getAlertsForLine(_ lineNumber: String) async throws -> [LineAlert] {
        let alerts = try await fetchAlerts()
        return alerts.filter { $0.affectedLineNumber == lineNumber }
    }
    
    /// Returns alerts for a station (based on lines passing through it)
    func getAlertsForStation(lineNumbers: [String]) async throws -> [LineAlert] {
        let alerts = try await fetchAlerts()
        return alerts.filter { alert in
            guard let affectedLine = alert.affectedLineNumber else {
                return false
            }
            return lineNumbers.contains(affectedLine)
        }
    }
    
    /// Returns alerts for a route (based on lines used in the route)
    func getAlertsForRoute(lineNumbers: [String]) async throws -> [LineAlert] {
        let alerts = try await fetchAlerts()
        
        // Include general alerts and alerts for specific lines in the route
        return alerts.filter { alert in
            if alert.isGeneralAlert {
                return true
            }
            guard let affectedLine = alert.affectedLineNumber else {
                return false
            }
            return lineNumbers.contains(affectedLine)
        }
    }
    
    /// Clears the cache
    func clearCache() {
        cachedAlerts = []
        lastFetchTime = nil
    }
}
