// MapTapOptionsView.swift

import SwiftUI
import MapKit

@available(iOS 16.0, *)
struct MapTapOptionsView: View {
    let coordinate: CLLocationCoordinate2D
    var onAction: (MapTapAction, CLLocationCoordinate2D) -> Void
    var onDismiss: () -> Void

    var body: some View {
        // Re-add a navigation container to provide the title bar.
        NavigationView {
            List {
                Button(action: { onAction(.setAsOrigin, coordinate) }) {
                    Label(localizedString("set_as_origin"), systemImage: "circle.fill")
                        .foregroundColor(.primary)
                }
                
                Button(action: { onAction(.setAsDestination, coordinate) }) {
                    Label(localizedString("set_as_destination"), systemImage: "mappin.circle.fill")
                        .foregroundColor(.primary)
                }

                Button(action: { onAction(.viewNearbyStations, coordinate) }) {
                    Label(localizedString("view_nearby_stations"), systemImage: "mappin.and.ellipse")
                        .foregroundColor(.primary)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle(localizedString("map_tap_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizedString("close"), action: onDismiss)
                }
            }
        }
    }
}
