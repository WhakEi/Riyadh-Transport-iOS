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
                }
                
                Section(header: Text("cache")) {
                    Button(action: {
                        showingClearCacheAlert = true
                    }) {
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
                        Text("0.1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/WhakEi/Riyadh-Transport-Android")!) {
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
                    Button("done") {
                        dismiss()
                    }
                }
            }
            .alert("clear_cache", isPresented: $showingClearCacheAlert) {
                Button("cancel", role: .cancel) { }
                Button("clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("clear_cache_message")
            }
        }
    }
    
    private func clearCache() {
        // Clear URLCache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear UserDefaults cache (except favorites)
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }
}

#Preview {
    SettingsView()
}
