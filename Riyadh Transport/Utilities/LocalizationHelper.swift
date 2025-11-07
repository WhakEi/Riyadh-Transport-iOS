import Foundation

/// A custom localization function that explicitly loads the string from the bundle
/// corresponding to the user's selected language.
///
/// - Parameters:
///   - key: The key for the desired string in the `.strings` file.
///   - comment: A comment describing the purpose of the string.
/// - Returns: The localized string.
func localizedString(_ key: String, comment: String = "") -> String {
    let selectedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
    
    // Find the path for the language-specific .lproj directory
    guard let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        // Fallback to the main bundle if the specific language bundle isn't found.
        // This will return the key itself if the key is not in the base language file.
        return NSLocalizedString(key, comment: comment)
    }
    
    // Use the specific language bundle for the lookup
    return bundle.localizedString(forKey: key, value: nil, table: nil)
}
