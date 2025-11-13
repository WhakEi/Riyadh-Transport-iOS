# Build Notes for watchOS Companion App

## File Organization

### watchOS-Specific Files (in `Riyadh Transport Watch App/`)
- `RiyadhTransportWatchApp.swift` - Main app entry point
- `WatchContentView.swift` - Main menu with navigation
- `WatchRouteView.swift` - Route planning feature
- `WatchNearbyStationsView.swift` - Compass-based nearby stations
- `WatchStationDetailView.swift` - Station details with live arrivals
- `WatchConnectivityManager.swift` - Controls syncing of favorites as well as search history from iPhone
- `Info.plist` - watchOS app configuration
- `Assets.xcassets/` - watchOS app icons and assets
- `README.md` - Setup and usage documentation
- `BUILD_NOTES.md` - This file

### Shared Files (from iOS app)

These files need to be added to both iOS and watchOS targets in Xcode:

**Models** (`Riyadh Transport/Models/`)
- `Station.swift` - Station data model
- `Route.swift` - Route data model
- `RouteSegment.swift` - Route segment model
- `SearchResult.swift` - Search result model
- `Line.swift` - Transit line model
- `Arrival.swift` - Arrival data model

**Services** (`Riyadh Transport/Services/`)
- `APIService.swift` - Backend API communication
- `LiveArrivalService.swift` - Live arrival data service

**Utilities** (`Riyadh Transport/Utilities/`)
- `LocationManager.swift` - GPS location services
- `FavoritesManager.swift` - Favorites and history management
- `LocalizationHelper.swift` - Localization support
- `LineColorHelper.swift` - Transit line color utilities
- `LiveArrivalIndicator.swift` - Display arrival times

**Views/Managers** (`Riyadh Transport/Views/`)
- `StationManager.swift` - Station data management

## Build Configuration

### watchOS Target Settings
- **Product Name**: Riyadh Transport Watch App
- **Deployment Target**: watchOS 8.6 or later
- **Supported Destinations**: Apple Watch
- **Language**: Swift
- **UI Framework**: SwiftUI

### Required Capabilities
- Location Services
- Internet access

### Info.plist Configuration
Key permissions configured:
- `NSLocationWhenInUseUsageDescription` - For GPS-based features
- `NSLocationAlwaysAndWhenInUseUsageDescription` - For location services
- `WKCompanionAppBundleIdentifier` - Links to iOS app
- `UIRequiredDeviceCapabilities` - Requires location-services

## Build Process

### Prerequisites
1. Xcode 14.0 or later
2. iOS 15.0+ SDK
3. watchOS 8.0+ SDK
4. Active Apple Developer account (for device testing)

### Adding the Target in Xcode

Since Xcode project files are binary and complex, the watchOS target must be added using Xcode:

1. Open `Riyadh Transport.xcodeproj` in Xcode
2. File → New → Target
3. Select watchOS → Watch App
4. Configure as per settings above
5. Delete generated files, use existing files from this directory
6. Add shared files to watchOS target via Target Membership checkboxes

### Build Steps

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Select Scheme**: Choose "Riyadh Transport Watch App" scheme
3. **Select Destination**: Choose Apple Watch simulator or device
4. **Build**: Product → Build (⌘B)
5. **Run**: Product → Run (⌘R)

### Common Build Issues

#### Issue: "No such module" errors
**Solution**: Ensure all shared files have the watchOS target checked in Target Membership

#### Issue: "Undefined symbols" for localization
**Solution**: Add `LocalizationHelper.swift` to watchOS target

#### Issue: Location permission not working
**Solution**: Verify Info.plist has both location permission keys

#### Issue: API calls failing
**Solution**: Ensure Info.plist allows arbitrary loads or add specific domain exceptions

## Testing

### Simulator Testing
1. Choose Apple Watch Series simulator (any generation)
2. Run the app
3. Test features:
   - Grant location permission when prompted
   - Test "Stations Near Me" with simulated location
   - Add favorites for route planning
   - Verify API calls work

### Device Testing
1. Pair Apple Watch with iPhone
2. Install iOS app on iPhone
3. Install watchOS app (will appear on watch automatically)
4. Test with real GPS data

### Test Scenarios

#### Feature 1: Search Route
- [ ] Can select destination from favorites
- [ ] Can select destination from favorite stations
- [ ] Can select destination from history
- [ ] Route instructions display correctly
- [ ] Can swipe between instruction slides
- [ ] Summary page shows correct information
- [ ] "Return to Menu" button works

#### Feature 2: Stations Near Me
- [ ] Compass view displays correctly
- [ ] Stations appear in correct relative positions
- [ ] Can tap stations to view details
- [ ] Center indicator shows user position
- [ ] Refresh works correctly

#### Feature 3: Station Detail
- [ ] Live arrivals display correctly
- [ ] Arrivals grouped by line and destination
- [ ] Upcoming arrivals shown
- [ ] Refresh button updates data
- [ ] Color coding matches metro lines

## Troubleshooting

### Location Services
If location is not working:
1. Check system Settings → Privacy → Location Services
2. Verify watchOS app has "While Using" permission
3. Try restarting the simulator/device

### Network Issues
If API calls fail:
1. Verify internet connectivity
2. Check backend server is accessible
3. Review API endpoint URLs in APIService.swift
4. Check for SSL/TLS certificate issues

### Data Not Showing
If stations/arrivals don't appear:
1. Check backend API is running
2. Verify API responses in console logs
3. Ensure StationManager is loading data
4. Check for decoding errors in logs

## Performance Considerations

### Battery Optimization
- Location updates stop when views disappear

### Memory Management
- Use weak references in closures
- Properly dispose of observers
- Limit cached data

### Network Efficiency
- Combine API calls where possible
- Cache station list after first load
- Use appropriate timeout values

## Resources

- [watchOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/watchos)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Core Location Documentation](https://developer.apple.com/documentation/corelocation)
- [watchOS App Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/WatchKitProgrammingGuide/)
