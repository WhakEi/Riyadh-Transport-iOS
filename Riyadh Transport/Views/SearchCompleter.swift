//
//  SearchCompleter.swift
//  Riyadh Transport
//
//  Manages search completion using Apple's MapKit.
//

import Foundation
import MapKit
import Combine

class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var queryFragment: String = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    
    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?

    override init() {
        completer = MKLocalSearchCompleter()
        // Bias search results to the Riyadh region for more relevance.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        
        super.init()
        completer.delegate = self
        
        // Use Combine to debounce search text changes, which is more efficient.
        cancellable = $queryFragment
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .assign(to: \.queryFragment, on: completer)
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // We only want to show results that have enough detail to be useful.
        self.completions = completer.results.filter { !$0.subtitle.isEmpty }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer failed with error: \(error.localizedDescription)")
    }
}
