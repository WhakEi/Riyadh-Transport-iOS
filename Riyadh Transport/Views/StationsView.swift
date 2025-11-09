import SwiftUI
import MapKit
import CoreLocation

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct StationsView: View {
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    
    @Binding var mapTappedCoordinate: CLLocationCoordinate2D?
    @Binding var mapAction: MapTapAction?
    @Binding var pendingNearbyCoordinate: CLLocationCoordinate2D?

    @EnvironmentObject var stationManager: StationManager
    @EnvironmentObject var locationManager: LocationManager
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"

    @State private var searchText = ""
    @State private var nearbyStations: [Station] = []
    @State private var isLoadingNearby = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // New state to track if we failed to get a GPS location.
    @State private var didFailToGetLocation = false

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
                TextField(localizedString("search_station"), text: $searchText)
                    .textFieldStyle(.plain).focused($isTextFieldFocused)
                    .autocapitalization(.none).disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
                }
            }
            .padding(12).background(Color(UIColor.secondarySystemBackground)).cornerRadius(10).padding()

            // The main content area now handles the new GPS failure state.
            if didFailToGetLocation {
                VStack(spacing: 16) {
                    Image(systemName: "location.slash.fill").font(.system(size: 50)).foregroundColor(.gray)
                    Text(localizedString("no_gps_found")).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoadingNearby && searchText.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredStations.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tram.fill").font(.system(size: 50)).foregroundColor(.gray)
                    Text(localizedString("no_stations_found")).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredStations) { station in
                    NavigationLink(destination: StationDetailView(station: station)) {
                        StationRowContent(station: station)
                    }
                }
                .listStyle(.plain)
            }
        }
        .alert(localizedString("error"), isPresented: $showingError) { Button(localizedString("ok"), role: .cancel) { } } message: { Text(errorMessage) }
        .onAppear {
            if let coordinate = pendingNearbyCoordinate {
                loadNearbyStations(at: coordinate)
                pendingNearbyCoordinate = nil
            } else if nearbyStations.isEmpty {
                loadNearbyStations()
            }
        }
        .onChange(of: selectedLanguage) { _ in
            nearbyStations = []
            didFailToGetLocation = false // Reset state on language change
            loadNearbyStations()
        }
    }

    // This function now contains the core logic for handling location fetching.
    private func loadNearbyStations(at coordinate: CLLocationCoordinate2D? = nil) {
        isLoadingNearby = true
        didFailToGetLocation = false // Reset error state at the start of each load.
        
        Task {
            let finalCoordinate: CLLocationCoordinate2D?
            
            if let coordinate = coordinate {
                // If a coordinate is passed in (from a map tap), use it immediately.
                finalCoordinate = coordinate
            } else {
                // Otherwise, asynchronously request the user's current location.
                if let location = await locationManager.requestLocation() {
                    finalCoordinate = location.coordinate
                } else {
                    // This is the failure case. Set the state and exit.
                    finalCoordinate = nil
                    await MainActor.run {
                        self.isLoadingNearby = false
                        self.didFailToGetLocation = true
                        self.nearbyStations = []
                    }
                }
            }
            
            // Only proceed if we successfully obtained a coordinate.
            guard let targetCoordinate = finalCoordinate else { return }
            
            do {
                let rawNearbyStations = try await APIService.shared.getNearbyStations(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
                let completeStations = stationManager.mergeNearbyStations(rawNearbyStations)
                await MainActor.run {
                    isLoadingNearby = false
                    nearbyStations = completeStations
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
        if distance <= 0 {
            return String(format: "%.4f, %.4f", station.latitude, station.longitude)
        }

        let distanceText: String
        if distance < 1000 {
            let format = localizedString("distance_in_meters")
            distanceText = String(format: format, distance)
        } else {
            let format = localizedString("distance_in_kilometers")
            distanceText = String(format: format, distance / 1000)
        }
        
        let durationMinutes = Int(ceil(station.durationInSeconds))
        let durationText: String
        if durationMinutes < 1 {
            durationText = localizedString("less_than_one_minute")
        } else {
            durationText = String(format: localizedString("minutes_count"), durationMinutes)
        }
        
        let format = localizedString("station_distance_and_duration")
        return String(format: format, distanceText, durationText)
    }

    @ViewBuilder
    private func StationRowContent(station: Station) -> some View {
        HStack {
            Image(systemName: station.isMetro ? "tram.fill" : "bus.fill")
                .foregroundColor(station.isMetro ? .blue : .green).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(station.displayName).font(.headline)
                Text(formatDistanceAndDuration(station: station)).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
