import SwiftUI
import MapKit

struct StationsView: View {
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var mapTappedCoordinate: CLLocationCoordinate2D?
    @Binding var mapAction: MapTapAction?
    
    @EnvironmentObject var stationManager: StationManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var nearbyStations: [Station] = []
    @State private var isLoadingNearby = true
    @State private var nearbyLocation: CLLocationCoordinate2D?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var filteredStations: [Station] {
        let stationsToFilter = searchText.isEmpty ? nearbyStations : stationManager.stations
        
        if searchText.isEmpty {
            return stationsToFilter
        } else {
            return stationsToFilter.filter {
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
            
            if isLoadingNearby && searchText.isEmpty {
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
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadNearbyStations()
        }
        .onChange(of: mapAction) { action in
            guard let action = action, action == .viewNearbyStations,
                  let coordinate = mapTappedCoordinate else { return }
            
            nearbyLocation = coordinate
            loadNearbyStations(at: coordinate)
        }
    }
    
    private func loadNearbyStations(at coordinate: CLLocationCoordinate2D? = nil) {
        isLoadingNearby = true
        
        let targetCoordinate: CLLocationCoordinate2D
        
        if let coordinate = coordinate {
            targetCoordinate = coordinate
        } else if let userLocation = locationManager.location?.coordinate {
            targetCoordinate = userLocation
        } else {
            // Fallback to Riyadh center
            targetCoordinate = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
        }
        
        APIService.shared.getNearbyStations(
            latitude: targetCoordinate.latitude,
            longitude: targetCoordinate.longitude
        ) { result in
            DispatchQueue.main.async {
                isLoadingNearby = false
                switch result {
                case .success(let stations):
                    nearbyStations = stations
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    nearbyStations = []
                }
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
    @State private var mapTappedCoordinate: CLLocationCoordinate2D?
    @State private var mapAction: MapTapAction?

    var body: some View {
        StationsView(
            region: $region,
            isTextFieldFocused: $isTextFieldFocused,
            mapTappedCoordinate: $mapTappedCoordinate,
            mapAction: $mapAction
        )
        .environmentObject(LocationManager())
        .environmentObject(FavoritesManager.shared)
        .environmentObject(StationManager.shared)
    }
}

#Preview {
    StationsViewPreviewWrapper()
}
