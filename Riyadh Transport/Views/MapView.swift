//
//  MapView.swift
//  Riyadh Transport
//
//  Apple Maps view wrapper
//

import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @State private var stations: [Station] = []
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    var route: Route?  // Optional route to display on map
    var allStations: [Station] = []  // All stations for route matching

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)

        // Add tap gesture recognizer for empty map areas
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)

        // Load and display only nearby stations at start
        loadNearbyStations(on: mapView, for: region.center)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Keep the region in sync with SwiftUI state
        if mapView.region.center.latitude != region.center.latitude ||
            mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
            // Each time region changes, reload nearby stations
            loadNearbyStations(on: mapView, for: region.center)
        }
        
        // Update route overlays when route changes
        context.coordinator.updateRoute(route, on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func loadNearbyStations(on mapView: MKMapView, for center: CLLocationCoordinate2D) {
        // Remove old annotations first
        let stationAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(stationAnnotations)

        APIService.shared.getNearbyStations(latitude: center.latitude, longitude: center.longitude) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let stations):
                    let annotations = stations.map { station -> MKPointAnnotation in
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = station.coordinate
                        annotation.title = station.displayName
                        annotation.subtitle = station.type?.capitalized
                        return annotation
                    }
                    mapView.addAnnotations(annotations)
                case .failure(let error):
                    print("Error loading nearby stations: \(error.localizedDescription)")
                }
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapView
        var currentRoute: Route?

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            
            // Call the callback if provided
            parent.onMapTap?(coordinate)
        }
        
        // Update route overlays on the map
        func updateRoute(_ route: Route?, on mapView: MKMapView) {
            // Remove existing overlays first
            mapView.removeOverlays(mapView.overlays)
            
            currentRoute = route
            
            guard let route = route else { return }
            
            // Draw route segments
            for segment in route.segments {
                if let coordinates = extractCoordinates(from: segment) {
                    let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                    mapView.addOverlay(polyline)
                }
            }
            
            // Adjust map region to show entire route
            if let firstSegment = route.segments.first,
               let lastSegment = route.segments.last,
               let firstCoords = extractCoordinates(from: firstSegment),
               let lastCoords = extractCoordinates(from: lastSegment),
               let startCoord = firstCoords.first,
               let endCoord = lastCoords.last {
                
                let minLat = min(startCoord.latitude, endCoord.latitude)
                let maxLat = max(startCoord.latitude, endCoord.latitude)
                let minLon = min(startCoord.longitude, endCoord.longitude)
                let maxLon = max(startCoord.longitude, endCoord.longitude)
                
                let center = CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: (maxLat - minLat) * 1.3,
                    longitudeDelta: (maxLon - minLon) * 1.3
                )
                
                let region = MKCoordinateRegion(center: center, span: span)
                mapView.setRegion(region, animated: true)
            }
        }
        
        // Extract coordinates from a route segment
        private func extractCoordinates(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            // First try to get coordinates from from/to fields
            if let coords = extractFromToCoordinates(from: segment) {
                return coords
            }
            
            // If from/to fields don't work, try to match station names with the stations list
            return extractFromStationNames(from: segment)
        }
        
        // Extract coordinates from from/to fields
        private func extractFromToCoordinates(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            guard let from = segment.from?.value as? [Any],
                  let to = segment.to?.value as? [Any],
                  from.count >= 2,
                  to.count >= 2 else {
                return nil
            }
            
            let fromLat = (from[0] as? NSNumber)?.doubleValue ?? 0.0
            let fromLon = (from[1] as? NSNumber)?.doubleValue ?? 0.0
            let toLat = (to[0] as? NSNumber)?.doubleValue ?? 0.0
            let toLon = (to[1] as? NSNumber)?.doubleValue ?? 0.0
            
            // Only return if coordinates are valid (not 0,0)
            if fromLat != 0.0 || fromLon != 0.0 || toLat != 0.0 || toLon != 0.0 {
                return [
                    CLLocationCoordinate2D(latitude: fromLat, longitude: fromLon),
                    CLLocationCoordinate2D(latitude: toLat, longitude: toLon)
                ]
            }
            
            return nil
        }
        
        // Extract coordinates by matching station names
        private func extractFromStationNames(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            guard let stationNames = segment.stations, !stationNames.isEmpty else {
                return nil
            }
            
            // Get first and last station names
            let firstStationName = stationNames.first ?? ""
            let lastStationName = stationNames.last ?? ""
            
            // Strip (Metro) or (Bus) suffix from station names
            let cleanFirstName = firstStationName
                .replacingOccurrences(of: "\\s*\\(Bus\\)\\s*$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\(Metro\\)\\s*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            let cleanLastName = lastStationName
                .replacingOccurrences(of: "\\s*\\(Bus\\)\\s*$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s*\\(Metro\\)\\s*$", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            
            // Try to find matching stations from all stations
            let allStations = parent.allStations
            
            let firstStation = allStations.first { station in
                station.displayName.localizedCaseInsensitiveCompare(cleanFirstName) == .orderedSame ||
                station.rawName.localizedCaseInsensitiveCompare(cleanFirstName) == .orderedSame
            }
            
            let lastStation = allStations.first { station in
                station.displayName.localizedCaseInsensitiveCompare(cleanLastName) == .orderedSame ||
                station.rawName.localizedCaseInsensitiveCompare(cleanLastName) == .orderedSame
            }
            
            if let firstStation = firstStation, let lastStation = lastStation {
                return [firstStation.coordinate, lastStation.coordinate]
            }
            
            return nil
        }
        
        // Allow simultaneous recognition with pan/zoom/rotation, but not with taps
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow with map navigation gestures, but not with other tap gestures
            // This ensures our tap doesn't interfere with annotation taps
            return !(otherGestureRecognizer is UITapGestureRecognizer) &&
                   (otherGestureRecognizer is UIPanGestureRecognizer || 
                    otherGestureRecognizer is UIPinchGestureRecognizer ||
                    otherGestureRecognizer is UIRotationGestureRecognizer)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            let identifier = "StationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                annotationView?.annotation = annotation
            }

            // Color code by type
            if let subtitle = annotation.subtitle as? String {
                if subtitle.lowercased().contains("metro") {
                    annotationView?.markerTintColor = .systemBlue
                } else if subtitle.lowercased().contains("bus") {
                    annotationView?.markerTintColor = .systemGreen
                }
            }

            return annotationView
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            // Each time region changes, reload nearby stations
            parent.loadNearbyStations(on: mapView, for: mapView.region.center)
        }
        
        // Render route overlays with colors based on segment type
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
