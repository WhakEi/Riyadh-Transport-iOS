//
//  WatchConnectivityManager.swift
//  Riyadh Transport Watch App
//
//  Manages communication from the iOS app to the watchOS app.
//

import Foundation
import WatchConnectivity
import Combine

@MainActor
class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    
    @Published var needsReload: UUID = UUID()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession on watchOS activated with state: \(activationState.rawValue)")
        }
        
        if activationState == .activated {
            if !session.receivedApplicationContext.isEmpty {
                // --- THIS IS THE FIX ---
                // This delegate method also runs on a background thread, so we must dispatch.
                DispatchQueue.main.async {
                    print("WCSession activated with existing context. Applying data.")
                    FavoritesManager.shared.update(from: session.receivedApplicationContext)
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // This delegate also runs on a background thread, so we must dispatch.
        DispatchQueue.main.async {
            print("Watch received live application context update. Applying data.")
            FavoritesManager.shared.update(from: applicationContext)
        }
    }
}
