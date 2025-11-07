//
//  SettingsView.swift
//  Riyadh Transport
//
//  Settings view
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"
    @State private var showingClearCacheAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("language")) {
                    Picker("language", selection: $selectedLanguage) {
                        Text("english").tag("en")
                        Text("arabic").tag("ar")
                    }
                    .pickerStyle(.segmented)
                    // When the language changes, clear all language caches for lines.
                    // This forces LinesView to refetch data in the new language.
                    .onChange(of: selectedLanguage) { _ in
                        clearLinesCache()
                    }
                }
                
                Section(header: Text("cache")) {
                    Button(action: { showingClearCacheAlert = true }) {
                        HStack {
                            Text("clear_cache")
                            Spacer()
                            Image(systemName: "trash")
                        }
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("about")) {
                    HStack {
                        Text("version")
                        Spacer()
                        Text("0.2.4")
                            .foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://github.com/WhakEi/Riyadh-Transport-iOS")!) {
                        HStack {
                            Text("source_code")
                            Spacer()
                            Image(systemName: "link")
                        }
                    }
                }
            }
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
            .alert("clear_cache", isPresented: $showingClearCacheAlert) {
                Button("cancel", role: .cancel) { }
                Button("clear", role: .destructive) { clearAllCaches() }
            } message: {
                Text("clear_cache_message")
            }
        }
    }
    
    /// Clears only the caches related to the list of lines.
    private func clearLinesCache() {
        CacheManager.shared.clearAllLanguageCaches(forBaseKey: CacheManager.metroLinesCacheKey)
        CacheManager.shared.clearAllLanguageCaches(forBaseKey: CacheManager.busLinesCacheKey)
    }
    
    /// Clears all app caches.
    private func clearAllCaches() {
        URLCache.shared.removeAllCachedResponses()
        clearLinesCache()
    }
}

#Preview { SettingsView() }
