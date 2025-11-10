//
//  LocationManager.swift
//  Riyadh Transport
//
//  Location services manager
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdatingLocation = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }
    
    func getCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        if let location = location {
            completion(location)
        } else {
            startUpdatingLocation()
            // Wait for location update
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                completion(self?.location)
                self?.stopUpdatingLocation()
            }
        }
    }
    
    // Async version for modern Swift concurrency
    func requestLocation() async -> CLLocation? {
        if let location = location {
            return location
        }
        
        startUpdatingLocation()
        
        // Wait for location update
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        let currentLocation = location
        stopUpdatingLocation()
        
        return currentLocation
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
