//
//  MapView.swift
//  Riyadh Transport
//
//  Apple Maps view wrapper
//

import SwiftUI
import MapKit

// A custom MKPolyline subclass to store route segment information.
private class RoutePolyline: MKPolyline {
    var segmentType: String?
    var lineName: String?
}

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var onMapTap: ((CLLocationCoordinate2D) -> Void)?
    var route: Route?
    var allStations: [Station] = []
    
    @State private var nearbyStationsTask: Task<Void, Never>?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleMapTap(_:)))
        tapGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(tapGesture)
        
        context.coordinator.loadNearbyStations(on: mapView, for: region.center)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        if mapView.region.center.latitude != region.center.latitude ||
            mapView.region.center.longitude != region.center.longitude {
            mapView.setRegion(region, animated: true)
        }
        
        // Pass all necessary data to the coordinator
        context.coordinator.parent = self
        context.coordinator.updateRoute(route, on: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: MapView
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
        
        func loadNearbyStations(on mapView: MKMapView, for center: CLLocationCoordinate2D) {
            nearbyStationsTask?.cancel()
            nearbyStationsTask = Task {
                do {
                    // Debounce to avoid excessive calls while panning
                    try await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    
                    let stations = try await APIService.shared.getNearbyStations(latitude: center.latitude, longitude: center.longitude)
                    guard !Task.isCancelled else { return }

                    let annotations = stations.map { station -> MKPointAnnotation in
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = station.coordinate
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
                    print("Error loading nearby stations: \((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)")
                }
            }
        }
        
        func updateRoute(_ route: Route?, on mapView: MKMapView) {
            mapView.removeOverlays(mapView.overlays)
            guard let route = route else { return }

            var allCoordinates: [CLLocationCoordinate2D] = []
            
            for segment in route.segments {
                if let coordinates = extractCoordinates(from: segment) {
                    // Use our custom RoutePolyline to store segment data.
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
        
        private func parseCoordinateValue(_ value: Any) -> Double? {
            if let number = value as? NSNumber {
                return number.doubleValue
            }
            if let string = value as? String, let doubleValue = Double(string) {
                return doubleValue
            }
            return nil
        }
        
        private func extractCoordinates(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            // Priority 1: Use the detailed coordinates array if it exists. This is the best data.
            if let routeCoordinates = segment.coordinates, !routeCoordinates.isEmpty {
                return routeCoordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
            }
            
            // Fallback 1: Try to get coordinates from the 'from' and 'to' fields.
            if let coords = extractFromToCoordinates(from: segment) {
                return coords
            }
            
            // Fallback 2: Try to match station names from the master list.
            return extractFromStationNames(from: segment)
        }
        
        private func extractFromToCoordinates(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            guard let fromValue = segment.from?.value,
                  let toValue = segment.to?.value else {
                return nil
            }
            
            var startCoord: CLLocationCoordinate2D?
            var endCoord: CLLocationCoordinate2D?
            
            // Parse the 'from' coordinate
            if let fromDict = fromValue as? [String: Any],
               let lat = fromDict["lat"] as? Double,
               let lng = fromDict["lng"] as? Double {
                startCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            } else if let fromArray = fromValue as? [Any], fromArray.count >= 2,
                      let lat = parseCoordinateValue(fromArray[0]),
                      let lon = parseCoordinateValue(fromArray[1]) {
                startCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            
            // Parse the 'to' coordinate
            if let toDict = toValue as? [String: Any],
               let lat = toDict["lat"] as? Double,
               let lng = toDict["lng"] as? Double {
                endCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            } else if let toArray = toValue as? [Any], toArray.count >= 2,
                      let lat = parseCoordinateValue(toArray[0]),
                      let lon = parseCoordinateValue(toArray[1]) {
                endCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }

            if let start = startCoord, let end = endCoord {
                return [start, end]
            }
            
            return nil
        }
        
        private func extractFromStationNames(from segment: RouteSegment) -> [CLLocationCoordinate2D]? {
            guard let stationNames = segment.stations, stationNames.count >= 2 else {
                return nil
            }
            
            let firstStationName = stationNames.first!
            let lastStationName = stationNames.last!
            
            let cleanFirstName = firstStationName.replacingOccurrences(of: "\\s*\\(Bus\\)|\\(Metro\\)\\s*$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let cleanLastName = lastStationName.replacingOccurrences(of: "\\s*\\(Bus\\)|\\(Metro\\)\\s*$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            
            let allStations = parent.allStations
            let firstStation = allStations.first { $0.displayName.caseInsensitiveCompare(cleanFirstName) == .orderedSame || $0.rawName.caseInsensitiveCompare(cleanFirstName) == .orderedSame }
            let lastStation = allStations.first { $0.displayName.caseInsensitiveCompare(cleanLastName) == .orderedSame || $0.rawName.caseInsensitiveCompare(cleanLastName) == .orderedSame }
            
            if let firstCoord = firstStation?.coordinate, let lastCoord = lastStation?.coordinate {
                return [firstCoord, lastCoord]
            }
            
            return nil
        }
        
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

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
            loadNearbyStations(on: mapView, for: mapView.region.center)
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Check if the overlay is our custom RoutePolyline.
            if let polyline = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // Use the helper to get the correct SwiftUI Color, then convert it to UIColor.
                let swiftUIColor = LineColorHelper.getColorForSegment(type: polyline.segmentType, line: polyline.lineName)
                renderer.strokeColor = UIColor(swiftUIColor)
                
                // Make walking segments appear dashed.
                if polyline.segmentType?.lowercased() == "walk" {
                    renderer.lineDashPattern = [2, 5]
                }
                
                renderer.lineWidth = 5
                return renderer
            }
            
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
