//
//  APIService.swift
//  Riyadh Transport
//
//  API service for backend communication
//

import Foundation
import CoreLocation

enum APIServiceError: Error, LocalizedError {
    case invalidURL, noDataReceived, noRouteFound
    case decodingError(Error), networkError(Error), jsonError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "The URL provided was invalid."
        case .noDataReceived: return "No data was received from the server."
        case .decodingError(let error): return "Failed to decode the response: \(error.localizedDescription)"
        case .networkError(let error): return "A network error occurred: \(error.localizedDescription)"
        case .noRouteFound: return "A route could not be found between these locations."
        case .jsonError(let message): return message
        }
    }
}

private struct RouteResponse: Codable { let routes: [Route] }
private struct StationsResponse: Codable { let stations: [String] }
// FIX: Add Equatable conformance to the struct
struct StationLinesResponse: Codable, Equatable {
    let metroLines: [String]
    let busLines: [String]
    
    enum CodingKeys: String, CodingKey {
        case metroLines = "metro_lines"
        case busLines = "bus_lines"
    }
}


class APIService {
    static let shared = APIService()
    private let baseURL = "https://mainserver.inirl.net:5002/"
    private init() {}
    
    private func localizedEndpoint(for path: String) -> String {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        return baseURL + (selectedLanguage == "ar" ? "ar/" : "") + path
    }
    
    // MARK: - Stations
    func getStations() async throws -> [Station] {
        try await performRequest(endpoint: localizedEndpoint(for: "api/stations"))
    }
    
    // This function is now corrected to return the raw, coordinate-less model.
    func getNearbyStations(latitude: Double, longitude: Double) async throws -> [NearbyStationRaw] {
        let parameters: [String: Any] = ["lat": latitude, "lng": longitude]
        return try await performRequest(endpoint: localizedEndpoint(for: "nearbystations"), method: "POST", parameters: parameters)
    }
    
    // MARK: - Routes
    func findRoute(startLat: Double, startLng: Double, endLat: Double, endLng: Double) async throws -> Route {
        let parameters: [String: Any] = ["start_lat": startLat, "start_lng": startLng, "end_lat": endLat, "end_lng": endLng]
        let response: RouteResponse = try await performRequest(endpoint: localizedEndpoint(for: "route_from_coords"), method: "POST", parameters: parameters)
        if let route = response.routes.first { return route } else { throw APIServiceError.noRouteFound }
    }
    
    
    // MARK: - Arrivals
    func getMetroArrivals(stationName: String) async throws -> [String: Any] {
        let parameters: [String: String] = ["station_name": stationName]
        return try await performRequestJSON(endpoint: localizedEndpoint(for: "metro_arrivals"), method: "POST", parameters: parameters)
    }

    func getBusArrivals(stationName: String) async throws -> [String: Any] {
        let parameters: [String: String] = ["station_name": stationName]
        return try await performRequestJSON(endpoint: localizedEndpoint(for: "bus_arrivals"), method: "POST", parameters: parameters)
    }
    
    // MARK: - Lines
    func getBusLines() async throws -> [String: Any] { try await performRequestJSON(endpoint: localizedEndpoint(for: "buslines")) }
    func getMetroLines() async throws -> [String: Any] { try await performRequestJSON(endpoint: localizedEndpoint(for: "mtrlines")) }

    // MARK: - Line Stations
    func getMetroStations(forLine lineId: String) async throws -> [String] {
        let parameters = ["line": lineId]
        let response: StationsResponse = try await performRequest(endpoint: localizedEndpoint(for: "viewmtr"), method: "POST", parameters: parameters)
        return response.stations
    }
    
    func getBusStations(forLine lineId: String) async throws -> [String: [String]] {
        let parameters = ["line": lineId]
        return try await performRequest(endpoint: localizedEndpoint(for: "viewbus"), method: "POST", parameters: parameters)
    }
    
    // MARK: - Station Lines
    func getLinesForStation(stationName: String) async throws -> StationLinesResponse {
        let parameters = ["station_name": stationName]
        return try await performRequest(endpoint: localizedEndpoint(for: "searchstation"), method: "POST", parameters: parameters)
    }
    
    // MARK: - Generic Handlers
    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET", parameters: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: endpoint) else { throw APIServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let params = parameters, method == "POST" { request.httpBody = try? JSONSerialization.data(withJSONObject: params) }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        }
        catch {
            if let responseString = String(data: data, encoding: .utf8) {
                print("--- APIService DECODING ERROR ---")
                print("Failed to decode \(T.self) from endpoint: \(endpoint)")
                print("Server Response:\n\(responseString)")
                print("---------------------------------")
            }
            throw APIServiceError.decodingError(error)
        }
    }
    
    private func performRequestJSON(endpoint: String, method: String = "GET", parameters: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else { throw APIServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let params = parameters, method == "POST" { request.httpBody = try? JSONSerialization.data(withJSONObject: params) }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else { throw APIServiceError.jsonError("Expected a JSON object.") }
        return dict
    }
}
