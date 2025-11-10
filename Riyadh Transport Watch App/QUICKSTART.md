# watchOS App Quick Start Guide

## TL;DR - Get Running in 5 Minutes

### Prerequisites
- Xcode 14.0+
- iOS 15.0+ SDK
- watchOS 8.0+ SDK

### Step 1: Open in Xcode (30 seconds)
```bash
cd "Riyadh Transport"
open "Riyadh Transport.xcodeproj"
```

### Step 2: Add watchOS Target (2 minutes)
1. File → New → Target
2. Select **watchOS** → **Watch App**
3. Product Name: `Riyadh Transport Watch App`
4. Bundle Identifier: `com.riyadhtransport.app.watchkitapp`
5. Language: **Swift**, UI: **SwiftUI**
6. Uncheck "Include Notification Scene"
7. Click **Finish**

### Step 3: Replace Generated Files (1 minute)
1. In Xcode, **delete** the auto-generated files:
   - `ContentView.swift` (generated)
   - App file (generated)
   - Keep only `Assets.xcassets` and `Info.plist`

2. **Drag** the entire `Riyadh Transport Watch App/` folder into Xcode:
   - Check "Copy items if needed"
   - Select watchOS target
   - Click **Finish**

### Step 4: Link Shared Files (1 minute)
Select each file below and check the watchOS target in File Inspector (⌥⌘1):

**Quick Selection Method**:
1. Hold ⌘ and click these folders:
   - `Models/`
   - `Services/`
   - `Utilities/`
   
2. In File Inspector → Target Membership:
   - Check **Riyadh Transport Watch App**

**Individual files to check**:
- Models: `Station.swift`, `Route.swift`, `RouteSegment.swift`, `SearchResult.swift`, `Line.swift`, `Arrival.swift`
- Services: `APIService.swift`, `LiveArrivalService.swift`
- Utilities: `LocationManager.swift`, `FavoritesManager.swift`, `LocalizationHelper.swift`, `LineColorHelper.swift`
- Views: `StationManager.swift`

### Step 5: Build & Run (30 seconds)
1. Select scheme: **Riyadh Transport Watch App**
2. Select destination: **Apple Watch Series 8 (41mm)** (or any)
3. Press **⌘R** to build and run

### Expected Result
✅ Watch app launches with main menu
✅ Two buttons: "Search Route" and "Stations Near Me"
✅ Location permission prompt appears

### Quick Test
1. Features → Location → Custom Location → Riyadh
2. Tap "Stations Near Me"
3. See compass with nearby stations
4. Tap a station to view live arrivals

## Troubleshooting

### "No such module" errors
→ Check shared files have watchOS target membership

### Location not working
→ Grant permission when prompted, or check Settings → Privacy

### Build fails
→ Clean Build Folder (⇧⌘K), then rebuild

### Simulator issues
→ Restart simulator or try different watch size

## What You Get

### 3 Main Features
1. **Search Route** - Plan routes from your location
2. **Stations Near Me** - Compass view of nearby stations  
3. **Station Details** - Live arrival times

### No Additional Setup Needed
- No CocoaPods
- No dependencies
- No API keys
- Just add target and go!

## Next Steps

- Read [README.md](README.md) for detailed documentation
- Check [BUILD_NOTES.md](BUILD_NOTES.md) for testing guide
- See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for technical details

## Need Help?

### Common Questions

**Q: Do I need an iPhone app running?**  
A: No, the watch app works standalone in simulator

**Q: Does it work offline?**  
A: No, requires internet for API calls

**Q: Can I test on real Apple Watch?**  
A: Yes, but requires device pairing and provisioning

**Q: Where's the Xcode project file update?**  
A: Must be done manually - .xcodeproj is too complex to edit programmatically

**Q: Will this work with existing iOS app?**  
A: Yes, shares all models and services seamlessly

---

**That's it!** You should now have a working watchOS app. Happy coding! 🚇⌚
