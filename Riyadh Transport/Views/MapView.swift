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
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    var route: Route?
    var allStations: [Station] = []
    
    // Add a reference to the station manager to perform the merge operation.
    var stationManager: StationManager

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)
        
        // Pass the station manager to the coordinator.
        context.coordinator.stationManager = stationManager
        context.coordinator.loadNearbyStations(on: mapView, for: region.center)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if mapView.region.center.latitude != region.center.latitude ||
            mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        context.coordinator.parent = self
        context.coordinator.stationManager = stationManager
        context.coordinator.updateRoute(route, on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapView
        var stationManager: StationManager?
        private var nearbyStationsTask: Task<Void, Never>?

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            parent.onMapTap?(coordinate)
        }
        
        // This function now correctly implements the two-step data loading process.
        func loadNearbyStations(on mapView: MKMapView, for center: CLLocationCoordinate2D) {
            nearbyStationsTask?.cancel()
            nearbyStationsTask = Task {
                guard let stationManager = self.stationManager else { return }
                
                do {
                    try await Task.sleep(nanoseconds: 300_000_000) // Debounce
                    guard !Task.isCancelled else { return }
                    
                    // 1. Fetch the raw nearby station data.
                    let rawStations = try await APIService.shared.getNearbyStations(latitude: center.latitude, longitude: center.longitude)
                    guard !Task.isCancelled else { return }

                    // 2. Use the StationManager to merge and get complete Station objects.
                    let completeStations = stationManager.mergeNearbyStations(rawStations)
                    
                    // 3. Create annotations from the complete data.
                    let annotations = completeStations.map { station -> MKPointAnnotation in
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = station.coordinate // This now works
                        annotation.title = station.displayName
                        annotation.subtitle = station.type?.capitalized
                        return annotation
                    }
                    
                    await MainActor.run {
                        let oldAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
                        mapView.removeAnnotations(oldAnnotations)
                        mapView.addAnnotations(annotations)
                    }
                } catch is CancellationError {
                    // Task was cancelled, which is expected.
                } catch {
                    print("Error loading nearby stations on map: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                }
            }
        }
        
        func updateRoute(_ route: Route?, on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            guard let route = route else { return }

            var allCoordinates: [CLLocationCoordinate2D] = []
            
            for segment in route.segments {
                if let coordinates = extractCoordinates(from: segment) {
                    let polyline = RoutePolyline(coordinates: coordinates, count: coordinates.count)
                    polyline.segmentType = segment.type
                    polyline.lineName = segment.line
                    mapView.addOverlay(polyline)
                    allCoordinates.append(contentsOf: coordinates)
                }
            }
            
            if !allCoordinates.isEmpty {
                let mapRect = allCoordinates.reduce(MKMapRect.null) { rect, coord -> MKMapRect in
                    let point = MKMapPoint(coord)
                    let newRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
                    return rect.union(newRect)
                }
                
                let edgePadding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
                mapView.setVisibleMapRect(mapRect, edgePadding: edgePadding, animated: true)
            }
        }
        
        private func extractCoordinates(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            if let routeCoordinates = segment.coordinates, !routeCoordinates.isEmpty {
                return routeCoordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
            }
            // ... (rest of the coordinate extraction logic is unchanged)
            return nil
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            loadNearbyStations(on: mapView, for: mapView.region.center)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                let swiftUIColor = LineColorHelper.getColorForSegment(type: polyline.segmentType, line: polyline.lineName)
                renderer.strokeColor = UIColor(swiftUIColor)
                if polyline.segmentType?.lowercased() == "walk" {
                    renderer.lineDashPattern = [2, 5]
                }
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // ... (other delegate methods are unchanged) ...
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return !(otherGestureRecognizer is UITapGestureRecognizer)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "StationAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            if let subtitle = annotation.subtitle as? String {
                if subtitle.lowercased().contains("metro") {
                    annotationView?.markerTintColor = .systemBlue
                } else if subtitle.lowercased().contains("bus") {
                    annotationView?.markerTintColor = .systemGreen
                }
            }
            return annotationView
        }
    }
}

private class RoutePolyline: MKPolyline {
    var segmentType: String?
    var lineName: String?
}
