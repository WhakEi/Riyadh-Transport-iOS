import Foundation
import CoreLocation
import Combine

@MainActor
class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var heading: Double = 0.0 // For compass
    @Published var authorizationStatus: CLAuthorizationStatus

    // A continuation to bridge the delegate callback to the async function.
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// Asynchronously requests a single, current location update.
    /// - Returns: The user's `CLLocation` if successful, or `nil` if permission is denied or an error occurs.
    func requestLocation() async -> CLLocation? {
        // If we already have a recent location, return it immediately.
        if let location = self.location, location.timestamp.timeIntervalSinceNow > -60 {
             return location
        }
        
        // Ensure we have permission before requesting.
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("LocationManager: Permission not granted to request location.")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            manager.requestLocation() // Triggers the delegate method
        }
    }
    
    // MARK: - Continuous Updates for watchOS
    
    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
    
    func startUpdatingHeading() {
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }
    
    func stopUpdatingHeading() {
        if CLLocationManager.headingAvailable() {
            manager.stopUpdatingHeading()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.first
        self.location = newLocation
        
        // Fulfill the promise for the async function and then clear it.
        locationContinuation?.resume(returning: newLocation)
        locationContinuation = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // We use trueHeading which is relative to true north.
        self.heading = newHeading.trueHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed with error: \(error.localizedDescription)")
        
        // If the request fails, return nil to the async function.
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
    }
}
