//
//  ContentView.swift
//  Riyadh Transport
//
//  Main view with tabs and map
//

import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var stationManager: StationManager
    
    @AppStorage("selectedLanguage") private var selectedLanguage = "en"
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var bottomSheetOffset: CGFloat = 0
    @State private var isDragging = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var tappedCoordinate: CLLocationCoordinate2D?
    @State private var showingMapTapOptions = false
    @State private var selectedMapAction: MapTapAction?
    @State private var currentRoute: Route?
    
    private let minHeight: CGFloat = UIScreen.main.bounds.height * 0.5
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9
    
    var currentHeight: CGFloat { minHeight - bottomSheetOffset }
    private var smoothAnimation: Animation { .spring(response: 0.4, dampingFraction: 0.8) }
    
    var body: some View {
        NavigationView {
            ZStack {
                MapView(region: $region, onMapTap: { coordinate in
                    tappedCoordinate = coordinate
                    showingMapTapOptions = true
                }, route: currentRoute, allStations: stationManager.stations)
                    .ignoresSafeArea()
                    .onTapGesture { isTextFieldFocused = false }
                
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gear").font(.title2).foregroundColor(.white)
                                    .frame(width: 56, height: 56).background(Color.blue).clipShape(Circle()).shadow(radius: 4)
                            }
                            NavigationLink(destination: FavoritesView()) {
                                Image(systemName: "star.fill").font(.title2).foregroundColor(.white)
                                    .frame(width: 56, height: 56).background(Color.orange).clipShape(Circle()).shadow(radius: 4)
                            }
                        }.padding()
                    }
                    Spacer()
                }
                .padding(.top, 50)
                .opacity(currentHeight < maxHeight * 0.7 ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.2), value: currentHeight)
                
                VStack(spacing: 0) {
                    VStack {
                        RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.4)).frame(width: 40, height: 6)
                    }
                    .frame(height: 30).frame(maxWidth: .infinity).contentShape(Rectangle())
                    .gesture(dragGesture)
                    
                    Picker("Tab", selection: $selectedTab) {
                        Text("route_tab").tag(0)
                        Text("stations_tab").tag(1)
                        Text("lines_tab").tag(2)
                    }
                    .pickerStyle(.segmented).padding(.horizontal).padding(.bottom, 8)
                    
                    TabView(selection: $selectedTab) {
                        RouteView(region: $region, isTextFieldFocused: $isTextFieldFocused, mapTappedCoordinate: $tappedCoordinate, mapAction: $selectedMapAction, displayedRoute: $currentRoute).tag(0)
                        StationsView(region: $region, isTextFieldFocused: $isTextFieldFocused, mapTappedCoordinate: $tappedCoordinate, mapAction: $selectedMapAction).tag(1)
                        LinesView().tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .frame(height: currentHeight).frame(maxWidth: .infinity)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.2), radius: 10)
                .offset(y: UIScreen.main.bounds.height - currentHeight)
                .animation(isDragging ? nil : smoothAnimation, value: bottomSheetOffset)
            }
            .ignoresSafeArea(.keyboard)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .confirmationDialog("map_tap_title", isPresented: $showingMapTapOptions, titleVisibility: .visible) {
                Button("set_as_origin") { selectedMapAction = .setAsOrigin; selectedTab = 0 }
                Button("set_as_destination") { selectedMapAction = .setAsDestination; selectedTab = 0 }
                Button("view_nearby_stations") { selectedMapAction = .viewNearbyStations; selectedTab = 1 }
                Button("cancel", role: .cancel) { tappedCoordinate = nil }
            }
            .onAppear { locationManager.requestPermission() }
            .onChange(of: isTextFieldFocused) { isFocused in
                if isFocused { withAnimation(smoothAnimation) { bottomSheetOffset = -(maxHeight - minHeight) } }
            }
            .onChange(of: selectedTab) { _ in
                if selectedMapAction != nil {
                    selectedMapAction = nil
                    tappedCoordinate = nil
                }
            }
            // When the language changes, clear the current route.
            .onChange(of: selectedLanguage) { _ in
                currentRoute = nil
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                let translation = value.translation.height
                let proposedOffset = -translation
                let newHeight = minHeight - proposedOffset
                if newHeight < minHeight {
                    bottomSheetOffset = -( (minHeight - newHeight) * 0.3 )
                } else if newHeight > maxHeight {
                    bottomSheetOffset = -(maxHeight - minHeight + (newHeight - maxHeight) * 0.3)
                } else {
                    bottomSheetOffset = proposedOffset
                }
            }
            .onEnded { value in
                isDragging = false
                let velocity = value.predictedEndTranslation.height - value.translation.height
                withAnimation(smoothAnimation) {
                    if velocity < -500 { bottomSheetOffset = -(maxHeight - minHeight) }
                    else if velocity > 500 { bottomSheetOffset = 0 }
                    else if abs(velocity) > 100 { bottomSheetOffset = velocity < 0 ? -(maxHeight - minHeight) : 0 }
                    else { bottomSheetOffset = (minHeight - bottomSheetOffset) > (minHeight + maxHeight) / 2 ? -(maxHeight - minHeight) : 0 }
                }
            }
    }
}

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
