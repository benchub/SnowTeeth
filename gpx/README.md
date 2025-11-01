# GPX Viewer for macOS

A native macOS application for visualizing GPX files with synchronized elevation, speed, and map views.

## Features

- **Elevation Chart**: Displays elevation changes over the course of your GPX track with time axis showing minutes since start
  - Displays both raw GPS elevation (light blue, thin line) and smoothed elevation (dark blue, thick line)
  - **Intelligent Elevation Smoothing**: Two-stage filtering process
    - Stage 1: Accuracy-based filtering rejects readings with poor vertical accuracy (estimated from elevation variance)
    - Stage 2: Exponential Moving Average (EMA) with alpha=0.3 for gradual elevation changes
    - Eliminates false elevation spikes caused by tree canopy, buildings, or poor satellite geometry
    - Hover to see both smoothed and raw values
- **Speed Chart**: Shows speed variations throughout your journey with time axis showing minutes since start
  - Displays both raw GPS speed (light green, thin line) and smoothed speed (dark green, thick line)
  - **Intelligent GPS Spike Removal**: Two-stage filtering process
    - Stage 1: Spike rejection removes physically impossible values (> 30 m/s AND > 3× previous)
    - Stage 2: Exponential Moving Average (EMA) with alpha=0.6 for responsive smoothing
    - Preserves legitimate stops (speeds below 0.45 m/s = 1.6 km/h)
  - Helps visualize actual speed trends despite GPS noise and tracking errors
- **Satellite Map**: Visualizes your route on Apple Maps with satellite imagery
- **Synchronized Hover**: Mouse over the elevation or speed charts to see the corresponding point on all three views
- **Drag-to-Measure**: Click and drag on either chart to select a time range and see measurements:
  - **Elevation Chart**: Shows time difference and elevation change between two points
  - **Speed Chart**: Shows time difference and average speed over the selected range
  - Press Escape or click "Clear Selection" to remove the measurement
- **Unit Toggle**: Switch between Metric (meters, km/h) and Imperial (feet, mph) units
- **Interactive Map**: Zoom and pan the map using standard macOS gestures (pinch to zoom, click and drag to pan)
- **Smart Time Labels**: Automatically adjusts time interval labels based on track duration (2-60 minute intervals)

## Building the App

The easiest way to rebuild the app:

```bash
./build.sh
```

This script runs `swift build` and copies the binary to `build/GPXViewer.app`.

### Manual Build

Alternatively, you can build manually:

```bash
swift build
cp .build/arm64-apple-macosx/debug/GPXViewer build/GPXViewer.app/Contents/MacOS/GPXViewer
```

The app is then ready to run at `build/GPXViewer.app`.

## Using the App

1. Launch the app from `build/GPXViewer.app`
2. Click "Open GPX File" or use Cmd+O
3. Select a GPX file to visualize
4. Use the **Smoothing** slider (1-15 points) to adjust the intensity of speed smoothing in real-time
5. Use the **Metric/Imperial** toggle in the top-right to switch between unit systems
6. **Hover** over the elevation or speed charts to see synchronized markers across all views
7. **Click and drag** on either chart to select a time range and measure:
   - Time difference between two points
   - Elevation change (on elevation chart) or average speed (on speed chart)
   - Press **Escape** or click **Clear Selection** to remove the measurement
8. Zoom and pan the map using trackpad gestures or mouse scroll/drag

## Sample Data

Two sample GPX files are included for testing:
- `sample.gpx` - A simulated mountain trail with elevation changes from 100m to 400m (40 minutes)
- `sample2.gpx` - A coastal path with gentle elevation changes from 5m to 42m (15 minutes)

You can load multiple GPX files in sequence to test the app's ability to refresh all views.

## Technical Details

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Mapping**: MapKit with Apple's satellite imagery (no API key required)
- **Minimum macOS**: 13.0 (Ventura)

## File Structure

```
GPXViewer/
├── GPXViewerApp.swift          # App entry point
├── ContentView.swift           # Main view coordinator
├── Models.swift                # Data models
├── GPXParser.swift             # XML parser for GPX files
├── HoverCoordinator.swift      # Shared state for hover interaction
├── ElevationChartView.swift    # Elevation visualization
├── SpeedChartView.swift        # Speed visualization
├── MapView.swift               # Map with route overlay
├── TimeSeriesSmoothing.swift   # Reusable time-series smoothing module
├── Info.plist                  # App metadata
└── GPXViewer.entitlements      # App permissions
```

## TimeSeriesSmoothing Module

The `TimeSeriesSmoothing.swift` module provides a self-contained, reusable implementation for smoothing noisy GPS data. It can be easily extracted and used in other projects.

### Features

- **Velocity Smoothing**: Spike rejection + Exponential Moving Average (EMA)
  - Rejects physically impossible GPS spikes while preserving rapid speed changes
  - Responsive smoothing (alpha=0.6) appropriate for skiing/snowboarding
  - Preserves stops below minimum threshold
- **Elevation Smoothing**: Accuracy filtering + EMA
  - Rejects readings with poor vertical accuracy
  - Conservative smoothing (alpha=0.3) for gradual elevation changes
  - Eliminates tree canopy and satellite geometry effects
- **Real-time Processing**: Maintains state for sequential readings
- **Batch Processing**: Convenience methods for historical data
- **Well-Documented**: Comprehensive documentation with usage examples

### Velocity Smoothing Example

```swift
// Configure velocity smoother
let config = TimeSeriesSmoothing.VelocitySmootherConfig(
    absoluteMaxValue: 30.0,  // 30 m/s = 108 km/h
    spikeMultiplier: 3.0,    // Reject > 3× previous value
    minValueThreshold: 0.45, // Preserve stops < 0.45 m/s
    alpha: 0.6               // 60% new reading, 40% history
)

// Batch processing
let smoothedSpeeds = TimeSeriesSmoothing.smoothVelocities(rawSpeeds, config: config)

// Or real-time processing
let smoother = VelocitySmoother(config: config)
let smoothed = smoother.addReading(velocity)
```

### Elevation Smoothing Example

```swift
// Configure elevation smoother
let config = TimeSeriesSmoothing.ElevationSmootherConfig(
    verticalAccuracyThreshold: 15.0, // Reject readings with error > 15m
    alpha: 0.3                        // 30% new reading, 70% history
)

// Batch processing
let smoothedElevations = TimeSeriesSmoothing.smoothElevations(
    rawElevations,
    verticalAccuracies: accuracies,
    config: config
)

// Or real-time processing
let smoother = ElevationSmoother(config: config)
let smoothed = smoother.addReading(elevation, verticalAccuracy: accuracy)
```

### Reusability

The module is completely self-contained with no dependencies beyond Foundation. To use it in another project:

1. Copy `TimeSeriesSmoothing.swift` to your project
2. Import Foundation
3. Use the static methods on the `TimeSeriesSmoothing` struct
4. Or use `VelocitySmoother` / `ElevationSmoother` classes for real-time processing

The algorithms are based on the iOS/Android app implementations documented in `shared/algorithms/`.
