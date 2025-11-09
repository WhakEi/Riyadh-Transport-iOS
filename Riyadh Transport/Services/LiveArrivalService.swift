//
//  LiveArrivalService.swift
//  Riyadh Transport
//
//  Service for fetching live arrival data with fallback support
//

import Foundation

// Response models
struct LiveArrivalResponse: Codable {
    let arrivals: [LiveArrival]
    let stationName: String
    
    enum CodingKeys: String, CodingKey {
        case arrivals
        case stationName = "station_name"
    }
}

struct LiveArrival: Codable {
    let line: String
    let destination: String
    let minutesUntil: Int
    
    enum CodingKeys: String, CodingKey {
        case line
        case destination
        case minutesUntil = "minutes_until"
    }
}

struct StationIdResponse: Codable {
    let matches: [StationMatch]
    let stationName: String
    
    enum CodingKeys: String, CodingKey {
        case matches
        case stationName = "station_name"
    }
}

struct StationMatch: Codable {
    let fullStationName: String
    let stationId: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case fullStationName = "full_station_name"
        case stationId = "station_id"
        case type
    }
}

struct RawArrival: Codable {
    let number: String
    let name: String
    let destination: String
    let actualDepartureTimePlanned: String
    let departureTimePlanned: String
    
    enum CodingKeys: String, CodingKey {
        case number
        case name
        case destination
        case actualDepartureTimePlanned
        case departureTimePlanned
    }
}

struct RefineTerminusResponse: Codable {
    let apiDestination: String
    let lineNumber: String
    let refinedTerminus: String
    
    enum CodingKeys: String, CodingKey {
        case apiDestination = "api_destination"
        case lineNumber = "line_number"
        case refinedTerminus = "refined_terminus"
    }
}

class LiveArrivalService {
    static let shared = LiveArrivalService()
    private let baseURL = "https://mainserver.inirl.net:5002/"
    private let fallbackURL = "https://www.rpt.sa/en/web/guest/stationdetails"
    
    private init() {}
    
    private func localizedEndpoint(for path: String) -> String {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        return baseURL + (selectedLanguage == "ar" ? "ar/" : "") + path
    }
    
    // MARK: - Primary API Methods
    
    /// Fetch live arrivals for a station (primary method)
    func fetchLiveArrivals(stationName: String, type: String) async throws -> LiveArrivalResponse {
        let endpoint = type.lowercased() == "metro" ? "metro_arrivals" : "bus_arrivals"
        let parameters: [String: String] = ["station_name": stationName]
        
        do {
            let response: LiveArrivalResponse = try await performRequest(
                endpoint: localizedEndpoint(for: endpoint),
                method: "POST",
                parameters: parameters
            )
            return response
        } catch {
            // If primary API fails, try fallback
            return try await fetchLiveArrivalsFallback(stationName: stationName, type: type)
        }
    }
    
    // MARK: - Fallback Flow
    
    /// Fallback method when primary API fails
    private func fetchLiveArrivalsFallback(stationName: String, type: String) async throws -> LiveArrivalResponse {
        // Step 1: Get station ID
        let stationIdResponse = try await getStationId(stationName: stationName)
        
        guard let match = stationIdResponse.matches.first else {
            throw LiveArrivalError.noStationIdFound
        }
        
        // Step 2: Get raw arrivals from rpt.sa
        let rawArrivals = try await getRawArrivals(stationId: match.stationId)
        
        // Step 3: Convert raw arrivals to LiveArrival format
        var liveArrivals: [LiveArrival] = []
        
        for rawArrival in rawArrivals {
            // Parse the time and calculate minutes until departure
            let minutesUntil = try calculateMinutesUntil(from: rawArrival.actualDepartureTimePlanned)
            
            // Get refined terminus
            let refinedDestination = try await refineTerminus(
                lineNumber: rawArrival.number,
                apiDestination: rawArrival.destination
            )
            
            liveArrivals.append(LiveArrival(
                line: rawArrival.number,
                destination: refinedDestination,
                minutesUntil: minutesUntil
            ))
        }
        
        return LiveArrivalResponse(arrivals: liveArrivals, stationName: stationName)
    }
    
    /// Step 1: Get station ID from station name
    private func getStationId(stationName: String) async throws -> StationIdResponse {
        let parameters: [String: String] = ["station_name": stationName]
        return try await performRequest(
            endpoint: localizedEndpoint(for: "giveMeId"),
            method: "POST",
            parameters: parameters
        )
    }
    
    /// Step 2: Get raw arrivals from rpt.sa website
    private func getRawArrivals(stationId: String) async throws -> [RawArrival] {
        let urlString = fallbackURL + "?p_p_id=com_rcrc_stations_RcrcStationDetailsPortlet_INSTANCE_53WVbOYPfpUF&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=%2Fdeparture-monitor&p_p_cacheability=cacheLevelPage"
        
        guard let url = URL(string: urlString) else {
            throw LiveArrivalError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        let bodyString = "_com_rcrc_stations_RcrcStationDetailsPortlet_INSTANCE_53WVbOYPfpUF_busStopId=\(stationId)"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let arrivals = try JSONDecoder().decode([RawArrival].self, from: data)
            return arrivals
        } catch {
            throw LiveArrivalError.decodingError(error)
        }
    }
    
    /// Step 3: Refine terminus destination name
    private func refineTerminus(lineNumber: String, apiDestination: String) async throws -> String {
        let parameters: [String: String] = [
            "line_number": lineNumber,
            "api_destination": apiDestination
        ]
        
        do {
            let response: RefineTerminusResponse = try await performRequest(
                endpoint: localizedEndpoint(for: "refineTerminus"),
                method: "POST",
                parameters: parameters
            )
            return response.refinedTerminus
        } catch {
            // If refinement fails, return original destination
            return apiDestination
        }
    }
    
    // MARK: - Helper Methods
    
    /// Calculate minutes until departure from ISO8601 timestamp
    private func calculateMinutesUntil(from isoString: String) throws -> Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let departureDate = formatter.date(from: isoString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let departureDate = formatter.date(from: isoString) else {
                throw LiveArrivalError.invalidDateFormat
            }
            let now = Date()
            let interval = departureDate.timeIntervalSince(now)
            return max(0, Int(interval / 60))
        }
        
        let now = Date()
        let interval = departureDate.timeIntervalSince(now)
        return max(0, Int(interval / 60))
    }
    
    // MARK: - Generic Request Handler
    
    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        parameters: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw LiveArrivalError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let params = parameters, method == "POST" {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("--- LiveArrivalService DECODING ERROR ---")
                print("Failed to decode \(T.self) from endpoint: \(endpoint)")
                print("Server Response:\n\(responseString)")
                print("-----------------------------------------")
            }
            throw LiveArrivalError.decodingError(error)
        }
    }
}

// MARK: - Error Types

enum LiveArrivalError: Error, LocalizedError {
    case invalidURL
    case noStationIdFound
    case invalidDateFormat
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL provided was invalid."
        case .noStationIdFound:
            return "Could not find station ID for the given station name."
        case .invalidDateFormat:
            return "Invalid date format in arrival data."
        case .decodingError(let error):
            return "Failed to decode the response: \(error.localizedDescription)"
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        }
    }
}
