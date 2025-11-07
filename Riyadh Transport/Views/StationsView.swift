import SwiftUI
import MapKit

struct StationsView: View {
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    
    @EnvironmentObject var stationManager: StationManager
    @State private var searchText = ""
    
    var filteredStations: [Station] {
        if searchText.isEmpty {
            return stationManager.stations
        } else {
            return stationManager.stations.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("search_station", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding()
            
            if stationManager.stations.isEmpty {
                 ProgressView()
                     .padding()
            } else if filteredStations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("no_stations_found")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredStations) { station in
                    NavigationLink(destination: StationDetailView(station: station)) {
                        HStack {
                            Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                                .foregroundColor(station.isMetro ? .blue : .green)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.displayName)
                                    .font(.headline)
                                Text(String(format: "%.4f, %.4f", station.latitude, station.longitude))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Optionally zoom to station on map
                            withAnimation {
                                region.center = station.coordinate
                            }
                            isTextFieldFocused = false
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// Preview wrapper to provide a FocusState binding for the preview
private struct StationsViewPreviewWrapper: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        StationsView(
            region: $region,
            isTextFieldFocused: $isTextFieldFocused
        )
        .environmentObject(LocationManager())
        .environmentObject(FavoritesManager.shared)
        .environmentObject(StationManager.shared)
    }
}

#Preview {
    StationsViewPreviewWrapper()
}
