//
//  SearchLocationView.swift
//  Riyadh Transport
//
//  Search location with autocomplete
//

import SwiftUI
import MapKit

struct SearchLocationView: View {
    @Binding var isPresented: Bool
    let onSelect: (SearchResult) -> Void
    
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationManager: StationManager
    
    @StateObject private var searchCompleter = SearchCompleter()
    @State private var isGeocoding = false

    private var query: String { searchCompleter.queryFragment }
    
    var filteredStations: [SearchResult] {
        guard !query.isEmpty else { return [] }
        return stationManager.stations
            .filter { $0.displayName.localizedCaseInsensitiveContains(query) }
            .prefix(10)
            .map { station in
                SearchResult(
                    name: station.displayName,
                    latitude: station.latitude,
                    longitude: station.longitude,
                    type: .station,
                    stationId: station.id
                )
            }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("search_location", text: $searchCompleter.queryFragment)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !query.isEmpty {
                        Button(action: { searchCompleter.queryFragment = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding()
                
                // Content Area
                ZStack {
                    // The List is always part of the view hierarchy now.
                    // Its content changes based on the state.
                    List {
                        if query.isEmpty {
                            if !favoritesManager.searchHistory.isEmpty {
                                Section(header: Text("recents")) {
                                    ForEach(favoritesManager.searchHistory) { result in
                                        Button(action: { selectResult(result) }) {
                                            SearchResultRow(result: result)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .onDelete { indexSet in
                                        favoritesManager.removeSearchHistory(atOffsets: indexSet)
                                    }
                                }
                            }
                        } else {
                            if !filteredStations.isEmpty {
                                Section(header: Text("stations")) {
                                    ForEach(filteredStations) { result in
                                        Button(action: { selectResult(result) }) {
                                            SearchResultRow(result: result)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            if !searchCompleter.completions.isEmpty {
                                Section(header: Text("locations")) {
                                    ForEach(searchCompleter.completions, id: \.self) { completion in
                                        Button(action: { selectCompletion(completion) }) {
                                            CompletionRow(completion: completion)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .opacity(shouldShowPlaceholder ? 0 : 1) // Hide list if a placeholder is showing
                    
                    // Placeholders (Progress, Empty History, No Results) are overlaid
                    if isGeocoding {
                        ProgressView()
                    } else if shouldShowPlaceholder {
                        if query.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("search_hint")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("no_results")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("search_location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // A helper to determine if we need to show a placeholder view.
    private var shouldShowPlaceholder: Bool {
        if query.isEmpty {
            return favoritesManager.searchHistory.isEmpty
        } else {
            return filteredStations.isEmpty && searchCompleter.completions.isEmpty
        }
    }
    
    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        isGeocoding = true
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            isGeocoding = false
            guard let mapItem = response?.mapItems.first else {
                if let error = error {
                    print("Error geocoding completion: \(error.localizedDescription)")
                }
                return
            }
            
            let coordinate = mapItem.placemark.coordinate
            let result = SearchResult(
                name: mapItem.name ?? completion.title,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                type: .location
            )
            
            selectResult(result)
        }
    }
    
    private func selectResult(_ result: SearchResult) {
        favoritesManager.addToSearchHistory(result)
        onSelect(result)
        isPresented = false
    }
}

// A view for showing native search completion results.
struct CompletionRow: View {
    let completion: MKLocalSearchCompletion
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.red)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(completion.title)
                    .font(.body)
                    .lineLimit(2)
                if !completion.subtitle.isEmpty {
                    Text(completion.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SearchResultRow: View {
    let result: SearchResult
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.type == .station ? "tram.fill" : "mappin.circle.fill")
                .foregroundColor(result.type == .station ? .blue : .red)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.body)
                    .lineLimit(2)
                
                Text(String(format: "%.4f, %.4f", result.latitude, result.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SearchLocationView(isPresented: .constant(true)) { _ in }
        .environmentObject(FavoritesManager.shared)
        .environmentObject(StationManager.shared)
}
