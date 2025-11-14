//
//  ContentView.swift
//  Riyadh Transport
//
//  Main view with tabs and map
//

import SwiftUI
import MapKit

// The main ContentView now acts as a dispatcher, selecting the correct
// implementation based on the iOS version.
struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationManager: StationManager

    @AppStorage("selectedLanguage") private var selectedLanguage = "en"

    @State private var selectedTab = 0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    @FocusState private var isTextFieldFocused: Bool
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var selectedMapAction: MapTapAction?
    @State private var currentRoute: Route?

    @State private var startLocation: String = ""
    @State private var endLocation: String = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    
    @State private var showNearbyStationsCoordinate: CLLocationCoordinate2D?

    var body: some View {
        if #available(iOS 16.0, *) {
            ContentView_iOS16(
                selectedTab: $selectedTab,
                region: $region,
                isTextFieldFocused: $isTextFieldFocused,
                tappedCoordinate: $tappedCoordinate,
                selectedMapAction: $selectedMapAction,
                currentRoute: $currentRoute,
                startLocation: $startLocation,
                endLocation: $endLocation,
                startCoordinate: $startCoordinate,
                endCoordinate: $endCoordinate,
                showNearbyStationsCoordinate: $showNearbyStationsCoordinate
            )
        } else {
            ContentView_iOS15_Fallback(
                selectedTab: $selectedTab,
                region: $region,
                isTextFieldFocused: $isTextFieldFocused,
                tappedCoordinate: $tappedCoordinate,
                selectedMapAction: $selectedMapAction,
                currentRoute: $currentRoute,
                startLocation: $startLocation,
                endLocation: $endLocation,
                startCoordinate: $startCoordinate,
                endCoordinate: $endCoordinate,
                showNearbyStationsCoordinate: $showNearbyStationsCoordinate
            )
        }
    }
}

// MARK: - iOS 16+ View (Modern Sheet Implementation)

@available(iOS 16.0, *)
struct ContentView_iOS16: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationManager: StationManager
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"

    @Binding var selectedTab: Int
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var tappedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedMapAction: MapTapAction?
    @Binding var currentRoute: Route?
    @Binding var startLocation: String
    @Binding var endLocation: String
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?
    @Binding var showNearbyStationsCoordinate: CLLocationCoordinate2D?

    enum ModalScreen: Identifiable {
        case panel, settings, favorites, mapTapOptions
        var id: Self { self }
    }

    @State private var activeModal: ModalScreen? = .panel
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        ZStack {
            MapView(region: $region, onMapTap: { coordinate in
                DispatchQueue.main.async {
                    tappedCoordinate = coordinate
                    activeModal = .mapTapOptions
                }
            }, route: currentRoute, allStations: stationManager.stations, stationManager: stationManager)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Button(action: { activeModal = .settings }) {
                            Image(systemName: "gear").font(.title2).foregroundColor(.white)
                                .frame(width: 56, height: 56).background(Color.blue).clipShape(Circle()).shadow(radius: 4)
                        }

                        Button(action: { activeModal = .favorites }) {
                            Image(systemName: "star.fill").font(.title2).foregroundColor(.white)
                                .frame(width: 56, height: 56).background(Color.orange).clipShape(Circle()).shadow(radius: 4)
                        }
                    }.padding()
                }
                Spacer()
            }
            .padding(.top, 50)
        }
        .sheet(item: $activeModal, onDismiss: {
            if activeModal == nil {
                activeModal = .panel
            }
        }) { item in
            let layoutDirection: LayoutDirection = selectedLanguage == "ar" ? .rightToLeft : .leftToRight
            
            switch item {
            case .panel:
                let panel = PanelView(
                    selectedTab: $selectedTab,
                    region: $region,
                    isTextFieldFocused: $isTextFieldFocused,
                    mapTappedCoordinate: $tappedCoordinate,
                    mapAction: $selectedMapAction,
                    displayedRoute: $currentRoute,
                    startLocation: $startLocation,
                    endLocation: $endLocation,
                    startCoordinate: $startCoordinate,
                    endCoordinate: $endCoordinate,
                    showNearbyStationsCoordinate: $showNearbyStationsCoordinate
                )
                .presentationDetents([.fraction(0.2), .medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .environment(\.layoutDirection, layoutDirection)

                if #available(iOS 16.4, *) {
                    panel.presentationBackgroundInteraction(.enabled(upThrough: .large))
                } else {
                    panel
                }
            case .settings:
                SettingsView()
                    .environment(\.layoutDirection, layoutDirection)
            case .favorites:
                FavoritesView()
                    .environment(\.layoutDirection, layoutDirection)
            case .mapTapOptions:
                if let coordinate = tappedCoordinate {
                    MapTapOptionsView(
                        coordinate: coordinate,
                        onAction: { action, coord in
                            handleMapAction(action: action, coordinate: coord)
                            activeModal = nil
                        },
                        onDismiss: {
                            activeModal = nil
                        }
                    )
                    .presentationDetents([.height(280)])
                    .environment(\.layoutDirection, layoutDirection)
                }
            }
        }
        .onAppear { locationManager.requestPermission() }
        .onChange(of: selectedLanguage) { _ in
            currentRoute = nil
            // Clear alert cache when language changes
            LineAlertService.shared.clearCache()
        }
    }

    private func handleMapAction(action: MapTapAction, coordinate: CLLocationCoordinate2D) {
        selectedMapAction = action
        tappedCoordinate = coordinate

        switch action {
        case .setAsOrigin:
            startCoordinate = coordinate
            startLocation = formatCoordinate(coordinate)
            selectedTab = 0
        case .setAsDestination:
            endCoordinate = coordinate
            endLocation = formatCoordinate(coordinate)
            selectedTab = 0
        case .viewNearbyStations:
            showNearbyStationsCoordinate = coordinate
            selectedTab = 1
        }
    }

    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - iOS 15 Fallback View (Native Modal Sheet, Dismissable)

struct ContentView_iOS15_Fallback: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var stationManager: StationManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"

    @Binding var selectedTab: Int
    @Binding var region: MKCoordinateRegion
    @FocusState.Binding var isTextFieldFocused: Bool
    @Binding var tappedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedMapAction: MapTapAction?
    @Binding var currentRoute: Route?
    @Binding var startLocation: String
    @Binding var endLocation: String
    @Binding var startCoordinate: CLLocationCoordinate2D?
    @Binding var endCoordinate: CLLocationCoordinate2D?
    @Binding var showNearbyStationsCoordinate: CLLocationCoordinate2D?

    @State private var showingSettings = false
    @State private var showingFavorites = false
    @State private var showingMapTapOptions = false

    @State private var isPanelPresented = true

    var body: some View {
        ZStack {
            MapView(region: $region, onMapTap: { coordinate in
                tappedCoordinate = coordinate
                showingMapTapOptions = true
            }, route: currentRoute, allStations: stationManager.stations, stationManager: stationManager)
                .ignoresSafeArea()
                .onTapGesture { isTextFieldFocused = false }

            // Floating controls
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Button(action: {
                            isTextFieldFocused = false
                            showingSettings = true
                        }) {
                            Image(systemName: "gear").font(.title2).foregroundColor(.white)
                                .frame(width: 56, height: 56).background(Color.blue).clipShape(Circle()).shadow(radius: 4)
                        }
                        Button(action: {
                            isTextFieldFocused = false
                            showingFavorites = true
                        }) {
                            Image(systemName: "star.fill").font(.title2).foregroundColor(.white)
                                .frame(width: 56, height: 56).background(Color.orange).clipShape(Circle()).shadow(radius: 4)
                        }
                    }.padding()
                }
                Spacer()
            }
            .padding(.top, 50)

            // Show bring-back-panel button anchored to bottom
            if !isPanelPresented {
                VStack {
                    Spacer()
                    Button(action: { isPanelPresented = true }) {
                        ChevronGrabber(direction: .up)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 40)
                            .background(.thickMaterial)
                            .cornerRadius(30)
                            .shadow(radius: 6)
                    }
                    .padding(.bottom, 20)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(), value: isPanelPresented)
            }
        }
        .sheet(isPresented: $isPanelPresented, onDismiss: {
            isTextFieldFocused = false
        }) {
            NavigationView {
                PanelView(
                    selectedTab: $selectedTab,
                    region: $region,
                    isTextFieldFocused: $isTextFieldFocused,
                    mapTappedCoordinate: $tappedCoordinate,
                    mapAction: $selectedMapAction,
                    displayedRoute: $currentRoute,
                    startLocation: $startLocation,
                    endLocation: $endLocation,
                    startCoordinate: $startCoordinate,
                    endCoordinate: $endCoordinate,
                    showNearbyStationsCoordinate: $showNearbyStationsCoordinate
                )
                .environmentObject(locationManager)
                .environmentObject(stationManager)
                .environmentObject(favoritesManager)
                .navigationBarHidden(true)
                .overlay(alignment: .top) {
                    ChevronGrabber(direction: .down)
                        .padding(10)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.layoutDirection, selectedLanguage == "ar" ? .rightToLeft : .leftToRight)
                .onDisappear { isTextFieldFocused = false }
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView()
                .environment(\.layoutDirection, selectedLanguage == "ar" ? .rightToLeft : .leftToRight)
                .onDisappear { isTextFieldFocused = false }
        }
        .confirmationDialog(localizedString("map_tap_title"), isPresented: $showingMapTapOptions, titleVisibility: .visible) {
            Button(localizedString("set_as_origin")) { handleMapAction(action: .setAsOrigin, coordinate: tappedCoordinate) }
            Button(localizedString("set_as_destination")) { handleMapAction(action: .setAsDestination, coordinate: tappedCoordinate) }
            Button(localizedString("view_nearby_stations")) { handleMapAction(action: .viewNearbyStations, coordinate: tappedCoordinate) }
            Button(localizedString("cancel"), role: .cancel) { tappedCoordinate = nil }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .onChange(of: isTextFieldFocused) { isFocused in
            if isFocused && isPanelPresented && !showingSettings && !showingFavorites && !showingMapTapOptions {
                // isPanelPresented = true // No need to set it, as it's already true to focus the field
            }
        }
        .onChange(of: selectedLanguage) { _ in
            currentRoute = nil
            // Clear alert cache when language changes
            LineAlertService.shared.clearCache()
        }
    }

    private func handleMapAction(action: MapTapAction, coordinate: CLLocationCoordinate2D?) {
        guard let coordinate = coordinate else { return }
        selectedMapAction = action
        tappedCoordinate = coordinate

        // Bring the panel up if an action is taken
        isPanelPresented = true

        switch action {
        case .setAsOrigin:
            startCoordinate = coordinate
            startLocation = formatCoordinate(coordinate)
            selectedTab = 0
        case .setAsDestination:
            endCoordinate = coordinate
            endLocation = formatCoordinate(coordinate)
            selectedTab = 0
        case .viewNearbyStations:
            showNearbyStationsCoordinate = coordinate
            selectedTab = 1
        }
    }

    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
}

// MARK: - ChevronGrabber View

struct ChevronGrabber: View {
    enum Direction { case up, down }
    let direction: Direction
    
    var body: some View {
        ChevronShape(direction: direction)
            .fill(Color.secondary.opacity(0.8))
            .frame(width: 40, height: 7)
    }
}

private struct ChevronShape: Shape {
    let direction: ChevronGrabber.Direction
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midWidth = rect.midX
        
        if direction == .up {
            path.move(to: CGPoint(x: 0, y: height * 0.8))
            path.addLine(to: CGPoint(x: midWidth, y: height * 0.2))
            path.addLine(to: CGPoint(x: width, y: height * 0.8))
        } else {
            path.move(to: CGPoint(x: 0, y: height * 0.2))
            path.addLine(to: CGPoint(x: midWidth, y: height * 0.8))
            path.addLine(to: CGPoint(x: width, y: height * 0.2))
        }
        
        return path.strokedPath(.init(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }
}


// MARK: - Shared Components

enum MapTapAction { case setAsOrigin, setAsDestination, viewNearbyStations }

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
