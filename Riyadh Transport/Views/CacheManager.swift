//
//  CacheManager.swift
//  Riyadh Transport
//
//  A simple generic cache manager for Codable objects.
//

import Foundation

// A wrapper to store the data along with the date it was cached.
struct CachedData<T: Codable>: Codable {
    let date: Date
    let data: T
}

class CacheManager {
    static let shared = CacheManager()
    private let userDefaults = UserDefaults.standard
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // Base keys for caching. The language code will be appended automatically.
    static let metroLinesCacheKey = "cachedMetroLines"
    static let busLinesCacheKey = "cachedBusLines"
    
    // A list of all languages your app supports for caching purposes.
    private let supportedLanguages = ["en", "ar"]

    private init() {}
    
    /// Generates a language-specific key (e.g., "cachedMetroLines_ar").
    private func localizedKey(for baseKey: String) -> String {
        let language = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        return "\(baseKey)_\(language)"
    }

    /// Saves a Codable object to the cache for the current language.
    func saveData<T: Codable>(_ data: T, forKey baseKey: String) {
        let key = localizedKey(for: baseKey)
        let wrappedData = CachedData(date: Date(), data: data)
        if let encoded = try? encoder.encode(wrappedData) {
            userDefaults.set(encoded, forKey: key)
            print("CacheManager: Saved data for key '\(key)'.")
        }
    }

    /// Loads a Codable object from the cache for the current language.
    func loadData<T: Codable>(forKey baseKey: String, maxAgeInDays: Int) -> T? {
        let key = localizedKey(for: baseKey)
        guard let savedData = userDefaults.object(forKey: key) as? Data,
              let wrappedData = try? decoder.decode(CachedData<T>.self, from: savedData) else {
            return nil
        }

        let expirationDate = Calendar.current.date(byAdding: .day, value: maxAgeInDays, to: wrappedData.date)
        
        if let expirationDate = expirationDate, expirationDate > Date() {
            print("CacheManager: Cache hit for key '\(key)'.")
            return wrappedData.data
        } else {
            print("CacheManager: Cache expired for key '\(key)'.")
            clearCache(forKey: key)
            return nil
        }
    }

    /// Removes a specific item from the cache.
    private func clearCache(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        print("CacheManager: Cleared cache for key '\(key)'.")
    }
    
    /// Removes the cache for a given base key across ALL supported languages.
    func clearAllLanguageCaches(forBaseKey baseKey: String) {
        print("CacheManager: Clearing all language caches for base key '\(baseKey)'...")
        for lang in supportedLanguages {
            let key = "\(baseKey)_\(lang)"
            clearCache(forKey: key)
        }
    }
}
