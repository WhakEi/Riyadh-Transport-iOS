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
    private var fallbackURL: String {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        return "https://www.rpt.sa/\(selectedLanguage)/web/guest/stationdetails"
    }
    
    private init() {}
    
    private func localizedEndpoint(for path: String) -> String {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        return baseURL + (selectedLanguage == "ar" ? "ar/" : "") + path
    }
    
    // MARK: - Primary API Methods
    
    /// Fetch live arrivals for a station (primary method)
    func fetchLiveArrivals(stationName: String, type: String) async throws -> LiveArrivalResponse {
        let cleanStationName = stationName.strippedStationSuffix()
        
        let endpoint = type.lowercased() == "metro" ? "metro_arrivals" : "bus_arrivals"
        let parameters: [String: String] = ["station_name": cleanStationName]
        
        do {
            let response: LiveArrivalResponse = try await performRequest(
                endpoint: localizedEndpoint(for: endpoint),
                method: "POST",
                parameters: parameters
            )
            if response.arrivals.isEmpty {
                print("--- LiveArrivalService: Primary API returned empty arrivals for '\(cleanStationName)'. Attempting fallback...")
                return try await fetchLiveArrivalsFallback(stationName: cleanStationName, type: type)
            }
            
            // Refine the terminus for each arrival from the primary API
            let refinedArrivals = try await withThrowingTaskGroup(of: LiveArrival.self) { group -> [LiveArrival] in
                for arrival in response.arrivals {
                    group.addTask {
                        let refinedDestination = try await self.refineTerminus(
                            lineNumber: arrival.line,
                            apiDestination: arrival.destination
                        )
                        return LiveArrival(
                            line: arrival.line,
                            destination: refinedDestination,
                            minutesUntil: arrival.minutesUntil
                        )
                    }
                }
                
                var results = [LiveArrival]()
                for try await arrival in group {
                    results.append(arrival)
                }
                return results
            }
            
            return LiveArrivalResponse(arrivals: refinedArrivals, stationName: response.stationName)

        } catch {
            print("--- LiveArrivalService: Primary API failed for '\(cleanStationName)'. Error: \(error.localizedDescription). Attempting fallback...")
            return try await fetchLiveArrivalsFallback(stationName: cleanStationName, type: type)
        }
    }
    
    // MARK: - Fallback Flow
    
    private func fetchLiveArrivalsFallback(stationName: String, type: String) async throws -> LiveArrivalResponse {
        do {
            let stationIdResponse = try await getStationId(stationName: stationName)
            
            guard let match = stationIdResponse.matches.first else {
                throw LiveArrivalError.noStationIdFound
            }
            
            let rawArrivals = try await getRawArrivals(stationId: match.stationId)
            
            let liveArrivals = try await withThrowingTaskGroup(of: LiveArrival.self) { group -> [LiveArrival] in
                for rawArrival in rawArrivals {
                    group.addTask {
                        let minutesUntil = try self.calculateMinutesUntil(from: rawArrival.actualDepartureTimePlanned)
                        let refinedDestination = try await self.refineTerminus(
                            lineNumber: rawArrival.number,
                            apiDestination: rawArrival.destination
                        )
                        return LiveArrival(
                            line: rawArrival.number,
                            destination: refinedDestination,
                            minutesUntil: minutesUntil
                        )
                    }
                }
                
                var results = [LiveArrival]()
                for try await arrival in group {
                    results.append(arrival)
                }
                return results
            }
            
            return LiveArrivalResponse(arrivals: liveArrivals, stationName: stationName)

        } catch {
            print("--- LiveArrivalService: Fallback failed for '\(stationName)'. Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getStationId(stationName: String) async throws -> StationIdResponse {
        let parameters: [String: String] = ["station_name": stationName]
        return try await performRequest(
            endpoint: localizedEndpoint(for: "giveMeId"),
            method: "POST",
            parameters: parameters
        )
    }
    
    private func getRawArrivals(stationId: String) async throws -> [RawArrival] {
        let urlString = fallbackURL + "?p_p_id=com_rcrc_stations_RcrcStationDetailsPortlet_INSTANCE_53WVbOYPfpUF&p_p_lifecycle=2&p_p_state=normal&p_p_mode=view&p_p_resource_id=%2Fdeparture-monitor&p_p_cacheability=cacheLevelPage"
        
        guard let url = URL(string: urlString) else {
            throw LiveArrivalError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        let bodyString = "_com_rcrc_stations_RcrcStationDetailsPortlet_INSTANCE_53WVbOYPfpUF_busStopId=\(stationId)"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("--- LiveArrivalService (Fallback): Sending request to \(url) with body: \(bodyString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("--- LiveArrivalService: Fallback HTTP \(httpResponse.statusCode)")
            throw LiveArrivalError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil))
        }
        
        do {
            return try JSONDecoder().decode([RawArrival].self, from: data)
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("--- LiveArrivalService DECODING ERROR (Fallback) ---")
                print("Failed to decode [RawArrival] from fallback endpoint:")
                print("Server Response:\n\(responseString)")
                print("-----------------------------------------")
            }
            throw LiveArrivalError.decodingError(error)
        }
    }
    
    /// Only call the refineTerminus API for bus lines; for metro, just return apiDestination.
    private func refineTerminus(lineNumber: String, apiDestination: String) async throws -> String {
        if isMetroLine(lineNumber) {
            return apiDestination
        }
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
            return apiDestination
        }
    }
    
    /// Identifies if the line is a metro line by your project rule: "1"..."6" (no letters)
    private func isMetroLine(_ lineNumber: String) -> Bool {
        if let num = Int(lineNumber), (1...6).contains(num), lineNumber.trimmingCharacters(in: .whitespacesAndNewlines) == String(num) {
            return true
        }
        return false
    }
    
    // MARK: - Helper Methods
    
    nonisolated private func calculateMinutesUntil(from isoString: String) throws -> Int {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let departureDate = formatter.date(from: isoString) else {
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
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let params = parameters, method == "POST" {
            request.httpBody = try? JSONSerialization.data(withJSONObject: params)
        }
        
        print("--- LiveArrivalService: Sending \(method) request to \(url)")
        if let parameters {
            print("--- LiveArrivalService: Parameters: \(parameters)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            print("--- LiveArrivalService: Received HTTP \(httpResponse.statusCode) from \(endpoint)")
            throw LiveArrivalError.networkError(NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: nil))
        }
        
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
