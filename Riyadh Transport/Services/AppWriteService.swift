//
//  AppWriteService.swift
//  Riyadh Transport
//
//  Service for fetching alerts from AppWrite
//

import Foundation

enum AppWriteError: Error, LocalizedError {
    case invalidURL
    case noDataReceived
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid AppWrite URL"
        case .noDataReceived:
            return "No data received from AppWrite"
        case .decodingError(let error):
            return "Failed to decode AppWrite response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

class AppWriteService {
    static let shared = AppWriteService()
    
    // AppWrite configuration
    private let projectId = "68f141dd000f83849c21"
    private let endpoint = "https://fra.cloud.appwrite.io/v1"
    private let databaseId = "68f146de0013ba3e183a"
    private let tableIdEnglish = "emptt"
    private let tableIdArabic = "arabic"
    
    private init() {}
    
    /// Fetches line alerts from AppWrite based on the current app language
    func fetchLineAlerts() async throws -> [LineAlert] {
        let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        let collectionId = selectedLanguage == "ar" ? tableIdArabic : tableIdEnglish
        
        let urlString = "\(endpoint)/databases/\(databaseId)/collections/\(collectionId)/documents"
        
        guard let url = URL(string: urlString) else {
            throw AppWriteError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(projectId, forHTTPHeaderField: "X-Appwrite-Project")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Debug: Print response for development
            #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("AppWrite Response: \(jsonString)")
            }
            #endif
            
            let response = try JSONDecoder().decode(LineAlertsResponse.self, from: data)
            return response.documents
        } catch let error as DecodingError {
            throw AppWriteError.decodingError(error)
        } catch {
            throw AppWriteError.networkError(error)
        }
    }
}
