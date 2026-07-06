# ATE CalorieTracker
### Premium Nutrition, Calorie & Weight Tracker for iOS

ATE is a beautiful, fluid, and privacy-first iOS calorie tracker and weight logging assistant. Built using modern SwiftUI design principles and SwiftData persistence, ATE combines premium dark-mode aesthetics (glassmorphism, vibrant gradients, custom typography) with a powerful offline search engine and smart API integrations.

---

## Key Features

* **Offline-First Food Library**: Query over 80,000 grocery items instantly via a pre-compiled, indexed SQLite database bundled directly within the app bundle. Treats hyphens as spaces and prioritizes prefix-based matches in a background thread for zero-latency searching.
* **Camera Barcode Scanner**: Built-in AVCaptureSession scanner supporting real-time EAN-8, EAN-13, UPCE, and generic barcodes. Instantly queries the local offline database first, with a seamless online fallback to the Open Food Facts API v2.
* **Dynamic Goals Screener**: A seamless onboarding flow displaying a demographics screening calculator on the first launch (persisted via `@AppStorage` across updates).
* **Caloric & Macro Saturation Glow**: Circular progress rings and linear macro progress bars change color saturation (+80% intensity) and project a color-matched glowing drop shadow once daily nutrition goals are exceeded.
* **Interactive Weight Tracker**: Monitor weight changes chronologically with custom segment scopes (`1W`, `1M`, `3M`, `ALL`) and responsive charts. Includes demographics onboarding to save a single baseline weight record on download date.
* **Premium Glassmorphic UI**: Beautiful dark-mode layouts incorporating custom radial gradients (deep purple for Goals, deep amber/yellow for Account), segmented overlays, custom font registration, and responsive tap feedback.

---

## Technology Stack

* **Framework**: SwiftUI (iOS 17.0+)
* **Database / Persistence**: SwiftData (automatic schema lightweight migrations)
* **Local Index Database**: SQLite3 (C-wrapper query layer in background queues)
* **Camera Scanner**: AVFoundation Capture Session metadata objects
* **AI Service**: Google Gemini API (`gemini-2.5-flash` model structure parsing)
* **Charts**: Swift Charts API

---

## Codebase Directory Structure

```
CalorieTracker/
├── CalorieTracker/
│   ├── CalorieTrackerApp.swift       # Application entry point
│   ├── ContentView.swift             # Floating tab bar & global sheet coordinator
│   ├── Models.swift                  # SwiftData FoodEntry and WeightEntry models
│   ├── Theme.swift                   # Color constants, font registration, & custom modifiers
│   ├── DashboardView.swift           # Daily calorie rings, logs list, & detail sheet overlay
│   ├── FoodSearchView.swift          # Offline SQLite background search engine & library list
│   ├── BarcodeScannerView.swift      # Live camera viewport, mock buttons, & confirmation card
│   ├── GoalsCalculatorView.swift     # Onboarding setup questionnaire & calculation logic
│   ├── GoalsView.swift               # Target caloric/macro adjust configurations
│   ├── WeightTrackerView.swift       # Weight history list & trend charts
│   ├── AccountView.swift             # Name preferences & weight unit selector (lbs / kg)
│   ├── RecentlyAddedFoodsView.swift  # Quick copy recent food logs with optimization
│   ├── GeminiService.swift           # TDEE calorie estimation logic
│   ├── opennutrition_foods.sqlite    # Bundled SQLite database file
│   └── Assets.xcassets/              # App icon and core color assets
└── CalorieTracker.xcodeproj          # Xcode Project file
```

---

## Getting Started

### Prerequisites
* macOS with Xcode 15.0 or later.
* Target device/simulator running iOS 17.0 or later.

### Setup Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/ATE.git
   cd ATE
   ```
2. Open `CalorieTracker.xcodeproj` in Xcode.
3. Configure your **Signing & Capabilities** for the `CalorieTracker` target.
4. *(Optional)* Add a `Config.plist` file inside the `CalorieTracker/` directory to configure your Gemini API Key:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>GeminiAPIKey</key>
       <string>YOUR_ACTUAL_API_KEY_HERE</string>
   </dict>
   </plist>
   ```
5. Select a Simulator or physical iOS Device and press `⌘R` to build and run the application.

---

## 📄 License
This project is available under the MIT License.
