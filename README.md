# SnowTeeth

A GPS-based activity tracking app with real-time visualization for skiing, snowboarding, and other outdoor activities.

## Platform Support

SnowTeeth is available on **both iOS and Android** with feature parity maintained across platforms:
- **iOS**: Native Swift/SwiftUI implementation
- **Android**: Native Kotlin implementation

See [`shared/`](shared/README.md) for the unified specification of algorithms, constants, and data models shared between both platforms.

## Features

### Home Screen
- Four main navigation buttons:
  - Configuration
  - Visualization
  - Stats
  - Toggle Tracking

### Configuration Mode
- Adjust velocity thresholds for 7 activity buckets:
  - Downhill Hard (default: 10 mph)
  - Downhill Medium (default: 6 mph)
  - Downhill Easy (default: 2 mph)
  - Idle
  - Uphill Easy (default: 1 mph)
  - Uphill Medium (default: 3 mph)
  - Uphill Hard (default: 5 mph)
- Thresholds are validated to prevent overlaps
- Unit system selector: "Empire!" (mph) or "Science!" (km/h)
- Automatic threshold conversion when switching units
- Select visualization style: Flame, Data, or Yeti

### Visualization Mode
- Automatically enables tracking
- Keeps screen on during visualization
- Full-screen, immersive display
- Tap to exit
- Three visualization styles:
  - **Flame**: 3D volumetric fire effect using shader rendering
    - Intensity, color, and movement vary with velocity
    - Four presets: idle (gentle red), easy (orange), medium (yellow), hard (intense)
    - Real-time GPU-accelerated rendering
  - **Data**: Real-time GPS information display
    - Large velocity display with animated character morphing
    - Shows latitude, longitude, altitude
    - Clean monospaced numbers with smooth transitions
    - Updates every 2 seconds
  - **Yeti**: Video-based state machine visualization
    - Animated yeti character with 4 intensity states
    - Smooth one-step transitions between states
    - Multiple weighted video variants for natural loops

### Tracking Mode
- Records GPS location every second
- Writes GPX trackpoints every 10 seconds
- Runs as a foreground service with notification
- Tracks elevation changes for uphill/downhill detection

### Stats Mode
- Analyzes recorded GPX data to show:
  - Cumulative vertical feet up
  - Cumulative vertical feet down
  - Horizontal distance (miles or km)
  - Number of downhill runs
  - Number of uphill ascents
- Combines small pauses and elevation changes into continuous segments

## Technical Details

### Shared Implementation

Both iOS and Android implementations follow **identical specifications** for:
- **Algorithms**: Velocity calculation, GPS smoothing, point optimization, statistics
- **Constants**: Default thresholds, conversion factors, validation rules
- **Data Models**: Location data, velocity buckets, visualization styles
- **File Formats**: GPX structure and formatting

📚 **See [`shared/`](shared/README.md) for the complete specification** that both platforms implement.

This ensures:
- Consistent behavior across platforms
- Compatible GPX files (export on iOS, analyze on Android and vice versa)
- Same statistics calculations from identical GPS data
- Unified testing and validation

### iOS Architecture
- **Language**: Swift with SwiftUI
- **Min iOS**: 14.0
- **Architecture Pattern**: SwiftUI with MVVM and Combine
- **Key Components**:
  - `ContentView`: Home screen with navigation
  - `ConfigurationView`: Settings and threshold configuration
  - `VisualizationView`: Real-time visual feedback
  - `StatsView`: GPX analysis and statistics display
  - `LocationTrackingService`: CLLocationManager-based GPS service
  - `VelocityCalculator`: Core logic for bucket calculation
  - `GpxWriter`: GPX file generation
  - `StatsCalculator`: Track statistics computation

### Android Architecture
- **Language**: Kotlin
- **Min SDK**: 26 (Android 8.0)
- **Target SDK**: 34 (Android 14)
- **Architecture Pattern**: Activity-based with Service for location tracking
- **Key Components**:
  - `MainActivity`: Home screen with navigation
  - `ConfigurationActivity`: Settings and threshold configuration
  - `VisualizationActivity`: Real-time visual feedback
  - `StatsActivity`: GPX analysis and statistics display
  - `LocationTrackingService`: Background GPS tracking service
  - `VelocityCalculator`: Core logic for bucket calculation
  - `GpxWriter`: GPX file generation
  - `StatsCalculator`: Track statistics computation

### Permissions Required

**iOS**:
- Location Services (Always or When In Use)
- Background Location Updates

**Android**:
- `ACCESS_FINE_LOCATION`: For precise GPS tracking
- `ACCESS_COARSE_LOCATION`: For general location access
- `FOREGROUND_SERVICE`: For background tracking
- `FOREGROUND_SERVICE_LOCATION`: Android 14+ location service
- `POST_NOTIFICATIONS`: Android 13+ notification support
- `WAKE_LOCK`: Keep device awake during visualization

## Building the App

### iOS

#### Prerequisites
- Xcode 14.0 or later
- macOS 12.0 or later
- iOS device or simulator running iOS 14.0+

#### Setup
1. Clone the repository
2. Open `iOS/SnowTeeth.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on device or simulator

### Android

#### Prerequisites
- Android Studio Hedgehog (2023.1.1) or later
- JDK 17
- Android SDK with API level 34

#### Setup
1. Clone the repository
2. Open the `android/` directory in Android Studio
3. Generate Gradle wrapper:
   ```bash
   gradle wrapper --gradle-version 8.2
   ```
4. Sync Gradle files
5. Build and run on device or emulator

#### Building from Command Line
```bash
cd android
./gradlew assembleDebug
```

#### Running Tests
```bash
cd android
./gradlew test
```

## Testing

Both platforms include comprehensive unit tests for:
- `VelocityCalculator`: Bucket calculation and interpolation logic
- `StatsCalculator`: Distance, elevation, and segment counting
- `GpxWriter`: GPX file generation and point optimization

Test cases are designed to ensure **identical behavior** across platforms using the same test scenarios defined in [`shared/`](shared/README.md).

## Data Storage

### iOS
- **Preferences**: UserDefaults for app configuration
- **GPX Files**: Stored in Documents directory
- File name: `snowteeth_track.gpx`

### Android
- **Preferences**: SharedPreferences for app configuration
- **GPX Files**: Stored in app's external files directory
- File name: `snowteeth_track.gpx`

### File Compatibility
GPX files are **fully compatible** between platforms - you can:
- Record on iOS, analyze on Android
- Record on Android, analyze on iOS
- Share tracks between devices

## Future Enhancements

Potential features for future versions:
- Multiple visualization styles
- Historical track viewing
- Track export and sharing
- Advanced statistics (speed graphs, elevation profiles)
- Multiple GPX track management
- Cloud backup

## Project Structure

```
SnowTeeth/
├── README.md              # This file
├── shared/                # Unified specifications (algorithms, constants, models)
├── iOS/                   # iOS native implementation (Swift/SwiftUI)
├── android/               # Android native implementation (Kotlin)
├── docs/                  # Additional documentation
└── gpx/                   # Test GPX files and examples
```

## Contributing

When making changes to core functionality:

1. **Start with `shared/`**: Update algorithm documentation first
2. **Implement in both platforms**: Follow the shared specification exactly
3. **Test consistently**: Use same test scenarios on both platforms
4. **Verify compatibility**: Ensure GPX files work on both platforms

See [`shared/README.md`](shared/README.md) for detailed contribution guidelines.

## License

This project was created as a custom cross-platform application.

## Credits
Flame from https://www.shadertoy.com/view/wffXDr
Snow from xSnow
Icons from Bootstrap
