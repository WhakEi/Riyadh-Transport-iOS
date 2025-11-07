import SwiftUI
import MapKit

struct StationsView: View {
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var mapTappedCoordinate: CLLocationCoordinate2D?
    @Binding var mapAction: MapTapAction?
    
    @EnvironmentObject var stationManager: StationManager
    @EnvironmentObject var locationManager: LocationManager
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"
    
    @State private var searchText = ""
    @State private var nearbyStations: [Station] = []
    @State private var isLoadingNearby = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let defaultRiyadhCenter = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753)
    
    var filteredStations: [Station] {
        if searchText.isEmpty {
            return nearbyStations
        } else {
            return stationManager.stations.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("search_station", text: $searchText)
                    .textFieldStyle(.plain).focused($isTextFieldFocused)
                    .autocapitalization(.none).disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
                }
            }
            .padding(12).background(Color(UIColor.secondarySystemBackground)).cornerRadius(10).padding()
            
            if isLoadingNearby && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredStations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tram.fill").font(.system(size: 50)).foregroundColor(.gray)
                    Text("no_stations_found").foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredStations) { station in
                    NavigationLink(destination: StationDetailView(station: station)) {
                        HStack {
                            Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                                .foregroundColor(station.isMetro ? .blue : .green).frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(station.displayName).font(.headline)
                                Text(formatDistanceAndDuration(station: station)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { region.center = station.coordinate }
                            isTextFieldFocused = false
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert("Error", isPresented: $showingError) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
        .onAppear {
            if nearbyStations.isEmpty { loadNearbyStations() }
        }
        .onChange(of: mapAction) { action in
            guard let action = action, action == .viewNearbyStations, let coordinate = mapTappedCoordinate else { return }
            loadNearbyStations(at: coordinate)
        }
        // When the language changes, clear nearby stations and reload.
        .onChange(of: selectedLanguage) { _ in
            nearbyStations = []
            loadNearbyStations()
        }
    }
    
    private func loadNearbyStations(at coordinate: CLLocationCoordinate2D? = nil) {
        isLoadingNearby = true
        let targetCoordinate = coordinate ?? locationManager.location?.coordinate ?? defaultRiyadhCenter
        Task {
            do {
                let stations = try await APIService.shared.getNearbyStations(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
                await MainActor.run {
                    isLoadingNearby = false
                    nearbyStations = stations
                }
            } catch {
                await MainActor.run {
                    isLoadingNearby = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    showingError = true
                    nearbyStations = []
                }
            }
        }
    }
    
    private func formatDistanceAndDuration(station: Station) -> String {
        let distance = station.distanceInMeters
        if distance <= 0 { return String(format: "%.4f, %.4f", station.latitude, station.longitude) }
        let distanceText = distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
        let durationMinutes = Int(ceil(station.durationInSeconds / 60))
        let durationText = "\(durationMinutes) min"
        return "\(distanceText) away, \(durationText) walk"
    }
}
