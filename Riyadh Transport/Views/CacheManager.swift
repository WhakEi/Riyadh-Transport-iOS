//
//  CacheManager.swift
//  Riyadh Transport
//
//  A simple generic cache manager for Codable objects.
//

import Foundation

struct CachedData<T: Codable>: Codable {
    let date: Date
    let data: T
}

class CacheManager {
    static let shared = CacheManager()
    private let userDefaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    static let metroLinesCacheKey = "cachedMetroLines"
    static let busLinesCacheKey = "cachedBusLines"
    private let stationCachePrefix = "station_cache_line_"
    
    private let supportedLanguages = ["en", "ar"]

    private init() {}
    
    private func localizedKey(for baseKey: String) -> String {
        let language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        return "\(baseKey)_\(language)"
    }

    func saveData<T: Codable>(_ data: T, forKey baseKey: String) {
        let key = localizedKey(for: baseKey)
        let wrappedData = CachedData(date: Date(), data: data)
        if let encoded = try? encoder.encode(wrappedData) {
            userDefaults.set(encoded, forKey: key)
        }
    }

    func loadData<T: Codable>(forKey baseKey: String, maxAgeInDays: Int) -> T? {
        let key = localizedKey(for: baseKey)
        guard let savedData = userDefaults.object(forKey: key) as? Data,
              let wrappedData = try? decoder.decode(CachedData<T>.self, from: savedData) else {
            return nil
        }
        let expirationDate = Calendar.current.date(byAdding: .day, value: maxAgeInDays, to: wrappedData.date)
        if let expirationDate = expirationDate, expirationDate > Date() {
            return wrappedData.data
        } else {
            clearCache(forKey: key)
            return nil
        }
    }

    private func clearCache(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    func clearAllLanguageCaches(forBaseKey baseKey: String) {
        for lang in supportedLanguages {
            let key = "\(baseKey)_\(lang)"
            clearCache(forKey: key)
        }
    }
    
    // New method to clear all station terminus data.
    func clearAllStationData() {
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys where key.hasPrefix(stationCachePrefix) {
            userDefaults.removeObject(forKey: key)
        }
        print("CacheManager: Cleared all station terminus caches.")
    }
}
