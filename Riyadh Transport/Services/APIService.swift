//
//  APIService.swift
//  Riyadh Transport
//
//  API service for backend communication
//

import Foundation
import CoreLocation

// Add this new struct to handle the nested route response
private struct RouteResponse: Codable {
    let routes: [Route]
}

class APIService {
    static let shared = APIService()
    
    // Backend server URL
    private let baseURL = "https://mainserver.inirl.net:5002/"
    private let nominatimURL = "https://nominatim.openstreetmap.org/"
    
    private init() {}
    
    // MARK: - Stations
    
    func getStations(completion: @escaping (Result<[Station], Error>) -> Void) {
        let endpoint = baseURL + "api/stations"
        performRequest(endpoint: endpoint, completion: completion)
    }
    
    func getNearbyStations(latitude: Double, longitude: Double, completion: @escaping (Result<[Station], Error>) -> Void) {
        let endpoint = baseURL + "nearbystations"
        let parameters: [String: Any] = [
            "lat": latitude,
            "lng": longitude
        ]
        performRequest(endpoint: endpoint, method: "POST", parameters: parameters, completion: completion)
    }
    
    // MARK: - Routes
    
    func findRoute(startLat: Double, startLng: Double, endLat: Double, endLng: Double, completion: @escaping (Result<Route, Error>) -> Void) {
        let endpoint = baseURL + "route_from_coords"
        let parameters: [String: Any] = [
            "start_lat": startLat,
            "start_lng": startLng,
            "end_lat": endLat,
            "end_lng": endLng
        ]
        
        // The API returns a wrapper object with a "routes" array.
        // We decode this wrapper first, then extract the first route.
        performRequest(endpoint: endpoint, method: "POST", parameters: parameters) { (result: Result<RouteResponse, Error>) in
            switch result {
            case .success(let response):
                // Check if there is at least one route and pass it to the completion handler.
                if let firstRoute = response.routes.first {
                    completion(.success(firstRoute))
                } else {
                    // If the routes array is empty, it's a valid response but no route was found.
                    // We'll create a custom error to inform the user.
                    let noRouteError = NSError(domain: "APIService", code: 404, userInfo: [NSLocalizedDescriptionKey: "A route could not be found between these locations."])
                    completion(.failure(noRouteError))
                }
            case .failure(let error):
                // Pass the decoding or network error along.
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Arrivals (dictionary JSON)
    
    func getMetroArrivals(stationName: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = baseURL + "metro_arrivals"
        let parameters: [String: String] = ["station_name": stationName]
        performRequestJSON(endpoint: endpoint, method: "POST", parameters: parameters, completion: completion)
    }
    
    func getBusArrivals(stationName: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = baseURL + "bus_arrivals"
        let parameters: [String: String] = ["station_name": stationName]
        performRequestJSON(endpoint: endpoint, method: "POST", parameters: parameters, completion: completion)
    }
    
    // MARK: - Lines (dictionary JSON)
    
    func getBusLines(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = baseURL + "buslines"
        performRequestJSON(endpoint: endpoint, completion: completion)
    }
    
    func getMetroLines(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let endpoint = baseURL + "mtrlines"
        performRequestJSON(endpoint: endpoint, completion: completion)
    }
    
    // MARK: - Search
    
    func searchLocation(query: String, completion: @escaping (Result<[NominatimResult], Error>) -> Void) {
        let endpoint = nominatimURL + "search"
        guard var urlComponents = URLComponents(string: endpoint) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "countrycodes", value: "sa"),
            URLQueryItem(name: "bounded", value: "1"),
            URLQueryItem(name: "viewbox", value: "46.5,24.9,46.9,24.5") // Riyadh bounds
        ]
        
        guard let url = urlComponents.url else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("RiyadhTransportApp/1.0", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let results = try JSONDecoder().decode([NominatimResult].self, from: data)
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Generic Request Handlers
    
    // Decodes into a concrete Decodable type (e.g., [Station], Route)
    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET", parameters: [String: Any]? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let parameters = parameters, method == "POST" {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let result = try JSONDecoder().decode(T.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Returns raw JSON as [String: Any] using JSONSerialization
    private func performRequestJSON(endpoint: String, method: String = "GET", parameters: [String: Any]? = nil, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let parameters = parameters, method == "POST" {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                if let dict = jsonObject as? [String: Any] {
                    completion(.success(dict))
                } else {
                    completion(.failure(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Expected a JSON object"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Nominatim Result Model

struct NominatimResult: Codable {
    let displayName: String
    let lat: String
    let lon: String
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case lat
        case lon
    }
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(
            latitude: Double(lat) ?? 0.0,
            longitude: Double(lon) ?? 0.0
        )
    }
}
