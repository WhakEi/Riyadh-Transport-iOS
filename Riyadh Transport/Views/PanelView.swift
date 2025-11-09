// PanelView.swift

import SwiftUI
import MapKit

struct PanelView: View {
    @Binding var selectedTab: Int
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var mapTappedCoordinate: CLLocationCoordinate2D?
    @Binding var mapAction: MapTapAction?
    @Binding var displayedRoute: Route?

    // Bindings to the state owned by ContentView
    @Binding var startLocation: String
    @Binding var endLocation: String
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?

    // New: For passing the pending nearby-station coordinate
    @Binding var showNearbyStationsCoordinate: CLLocationCoordinate2D?

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                panelContent
                    .navigationDestination(for: Station.self) { station in
                        StationDetailView(station: station)
                    }
                    .navigationDestination(for: Line.self) { line in
                        LineDetailView(line: line)
                    }
            }
        } else {
            panelContent
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $selectedTab) {
                Text(localizedString("route_tab")).tag(0)
                Text(localizedString("stations_tab")).tag(1)
                Text(localizedString("lines_tab")).tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)

            TabView(selection: $selectedTab) {
                RouteView(
                    region: $region,
                    isTextFieldFocused: $isTextFieldFocused,
                    mapTappedCoordinate: $mapTappedCoordinate,
                    mapAction: $mapAction,
                    displayedRoute: $displayedRoute,
                    startLocation: $startLocation,
                    endLocation: $endLocation,
                    startCoordinate: $startCoordinate,
                    endCoordinate: $endCoordinate
                ).tag(0)

                StationsView(
                    region: $region,
                    isTextFieldFocused: $isTextFieldFocused,
                    mapTappedCoordinate: $mapTappedCoordinate,
                    mapAction: $mapAction,
                    pendingNearbyCoordinate: $showNearbyStationsCoordinate // <-- Pass here
                ).tag(1)

                LinesView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.top, 8) // This adds the necessary space for the grabber
    }
}
