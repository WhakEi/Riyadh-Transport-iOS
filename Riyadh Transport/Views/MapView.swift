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
        
        // Allow gesture recognizer to work alongside pan and zoom gestures only
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition with map pan and pinch gestures
            // but not with other tap gestures (like annotation taps)
            return otherGestureRecognizer is UIPanGestureRecognizer || 
                   otherGestureRecognizer is UIPinchGestureRecognizer ||
                   otherGestureRecognizer is UIRotationGestureRecognizer
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
    }
}
