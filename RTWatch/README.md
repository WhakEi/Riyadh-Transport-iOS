# Riyadh Transport - watchOS Companion App

This directory contains the watchOS companion app for Riyadh Transport. The app provides three main features optimized for the Apple Watch:

## Features

### 1. Search Route
- Always uses the user's GPS location as the starting point
- Destination selection from:
  - Favorite locations
  - Favorite stations
  - Recent search history
- No keyboard input due to screen size limitations
- Route instructions displayed as swipable slides
- Summary slide with "Return to Menu" button
- No map visualization (text-only instructions)

### 2. Stations Near Me
- Uses GPS to find nearby stations
- Displays stations on a compass layout
- Center dot represents user's position and facing direction
- Tap any station to view details
- No map visualization (compass view instead)

### 3. Station Detail View
- Shows live arrival times for selected station
- Displays closest arrivals grouped by line and destination
- Refresh button to update arrival times
- Shows upcoming arrivals for each line

## Setup Instructions

Since the watchOS target is not yet added to the Xcode project file, follow these steps:

### Adding the watchOS Target to Xcode

1. Open the project in Xcode:
   ```bash
   cd "Riyadh Transport"
   open "Riyadh Transport.xcodeproj"
   ```

2. Add a new watchOS target:
   - File → New → Target
   - Select "watchOS" → "Watch App"
   - Product Name: `Riyadh Transport Watch App`
   - Bundle Identifier: `com.riyadhtransport.app.watchkitapp`
   - Language: Swift
   - User Interface: SwiftUI
   - Uncheck "Include Notification Scene"

3. Delete the default files created by Xcode:
   - Delete the generated `ContentView.swift`
   - Delete the generated main app file
   - Keep only `Assets.xcassets` and `Info.plist`

4. Add the watchOS app files to the target:
   - Select all files in `Riyadh Transport Watch App/` directory
   - Drag them into the Xcode project navigator under the watchOS target
   - Check "Copy items if needed"
   - Select the watchOS target in "Add to targets"

5. Add shared files to the watchOS target:
   The following files from the iOS app need to be shared with the watchOS target.
   Select each file in Xcode and check the watchOS target in the File Inspector:
   
   **Models:**
   - `Models/Station.swift`
   - `Models/Route.swift`
   - `Models/RouteSegment.swift`
   - `Models/SearchResult.swift`
   - `Models/Line.swift`
   - `Models/Arrival.swift`
   
   **Services:**
   - `Services/APIService.swift`
   - `Services/LiveArrivalService.swift` (if separate from watchOS implementation)
   
   **Utilities:**
   - `Utilities/LocationManager.swift`
   - `Utilities/FavoritesManager.swift`
   - `Utilities/LocalizationHelper.swift`
   - `Utilities/LineColorHelper.swift`
   
   **Views (for shared components):**
   - `Views/StationManager.swift`

6. Configure build settings:
   - Select the watchOS target
   - Build Settings → Deployment → watchOS Deployment Target: 8.0 or later
   - General → Supported Destinations: Apple Watch

7. Update Info.plist:
   - The `Info.plist` in this directory is already configured
   - Verify `WKCompanionAppBundleIdentifier` matches your iOS app bundle identifier

8. Build and run:
   - Select "Riyadh Transport Watch App" scheme
   - Choose an Apple Watch simulator
   - Click Run (⌘R)

## Architecture

### Main Views
- **WatchContentView**: Main menu with navigation to features
- **WatchRouteView**: Route planning with destination picker
- **WatchNearbyStationsView**: Compass view of nearby stations
- **WatchStationDetailView**: Station details with live arrivals

### Shared Components
The watchOS app shares models, services, and utilities with the iOS app:
- Location services (LocationManager)
- API communication (APIService)
- Data models (Station, Route, etc.)
- Favorites management (FavoritesManager)

### Data Flow
1. User location is obtained via LocationManager
2. API calls made through shared APIService
3. Data models decoded using shared Codable models
4. UI rendered using SwiftUI views optimized for watchOS

## Technical Details

### Requirements
- watchOS 8.5 or later
- Swift 5.7 or later
- Location services permission
- Active internet connection for API calls

### Permissions
The app requires location permission to:
- Find nearby stations
- Use current location as route starting point

This is configured in `Info.plist`:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

### API Endpoints Used
- `/nearbystations` - Find stations near GPS coordinates
- `/route_from_coords` - Calculate route between coordinates
- `/metro_arrivals` - Get metro arrival times
- `/bus_arrivals` - Get bus arrival times

### Localization
The app will inherit localization settings from the iOS app through shared services.

## Testing

### On Simulator
1. Select watchOS simulator from scheme
2. Run the app
3. Use Features → Location → Custom Location in simulator to test GPS features

### On Device
1. Pair Apple Watch with iPhone
2. Install both iOS and watchOS apps
3. The watchOS app will appear on the watch automatically

## Known Limitations

- No offline mode (requires active internet connection)
- No map visualization (compass only)
- Destination selection limited to favorites and history (no keyboard search)
- The app depends entirely on GPS and cannot function without it
