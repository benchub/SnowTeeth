# GPS Update Indicator

## Overview
A real-time visual indicator displayed on all visualization screens that shows how recently the last GPS location update was received. This helps users and developers monitor GPS update frequency and diagnose location tracking issues.

## Purpose
- Provide real-time feedback on GPS update frequency
- Help diagnose GPS throttling or signal issues
- Visualize the freshness of location data being displayed
- Aid in debugging location tracking behavior across platforms

## Visual Design

### Position
- **Location**: Top-right corner of visualization screen
- **Layer**: Overlaid above all visualization content (highest z-order)

### Appearance
```
┌─────────────────────────────┐
│             GPS: 2.3s     ← │  (Indicator)
│                             │
│                             │
│    Visualization Content    │
│                             │
│                             │
└─────────────────────────────┘
```

### Styling
- **Font**: Monospace (for consistent number spacing)
- **Size**: Caption/small text (14sp Android, .caption iOS)
- **Background**: Semi-transparent black (50% opacity)
- **Padding**: 8dp/8pt
- **Corner Radius**: 8dp/8pt (rounded corners)
- **Margin**: 16dp/16pt from screen edges

## Display States

### State 1: No Data
- **Text**: `GPS: --`
- **Color**: Gray (#AAAAAA)
- **Meaning**: No GPS updates received yet

### State 2: Fresh Update
- **Text**: `GPS: now`
- **Color**: Green (#00FF00)
- **Meaning**: Update received within the last 1 second

### State 3: Recent Update
- **Text**: `GPS: X.Xs` (e.g., "GPS: 2.3s")
- **Color**: Color-coded by staleness
- **Meaning**: Shows elapsed time since last update

## Color Coding

Updates use color to indicate data freshness:

| Time Range | Color | Hex Code | Meaning |
|------------|-------|----------|---------|
| < 2 seconds | Green | #00FF00 | Fresh - data is current |
| 2-5 seconds | Yellow | #FFFF00 | Aging - data is relatively recent |
| 5-10 seconds | Orange | #FF8800 | Stale - data is old |
| > 10 seconds | Red | #FF0000 | Very stale - significant delay |

## Behavior

### Update Frequency
- Timer refreshes display every **1 second**
- Does not wait for GPS updates (runs independently)

### Calculation
```
elapsedTime = currentTime - lastGpsUpdateTime

if elapsedTime < 1.0:
    display "GPS: now"
else:
    display "GPS: X.Xs" with elapsed time to 1 decimal place
```

### Lifecycle
- **Start**: Timer begins when visualization screen appears (`onResume`/`onAppear`)
- **Stop**: Timer stops when visualization screen disappears (`onPause`/`onDisappear`)
- **Reset**: Updates whenever new GPS location is received

## Platform Implementation

### iOS (SwiftUI)

**File**: `Views/VisualizationView.swift`

**Components**:
- SwiftUI `Text` view in `ZStack` overlay
- Combine `Timer.publish()` for 1-second updates
- `@State` variables for tracking time
- `.onChange(of: locationService.currentLocation)` to detect GPS updates

**Example**:
```swift
@State private var lastGpsUpdateTime: Date?
@State private var currentTime = Date()
let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

// In body
Text(gpsIndicatorText)
    .font(.system(.caption, design: .monospaced))
    .foregroundColor(gpsIndicatorColor)
    .padding(8)
    .background(Color.black.opacity(0.5))
    .cornerRadius(8)
    .onReceive(timer) { _ in currentTime = Date() }
    .onChange(of: locationService.currentLocation) { _ in
        lastGpsUpdateTime = Date()
    }
```

### Android (Kotlin)

**File**: `VisualizationActivity.kt`

**Components**:
- `TextView` in XML layout with `id="@+id/gpsUpdateIndicator"`
- `Handler` with `Runnable` for 1-second updates
- Track `lastGpsUpdateTime: Long` in milliseconds
- Update in `handleLocationUpdate()` when GPS data arrives

**Example**:
```kotlin
private var lastGpsUpdateTime: Long = 0
private val updateHandler = Handler(Looper.getMainLooper())
private val updateRunnable = object : Runnable {
    override fun run() {
        updateGpsIndicator()
        updateHandler.postDelayed(this, 1000)
    }
}

// In handleLocationUpdate()
lastGpsUpdateTime = System.currentTimeMillis()

// In onResume()
updateHandler.post(updateRunnable)

// In onPause()
updateHandler.removeCallbacks(updateRunnable)
```

**Layout (XML)**:
```xml
<TextView
    android:id="@+id/gpsUpdateIndicator"
    android:layout_width="wrap_content"
    android:layout_height="wrap_content"
    android:layout_gravity="top|end"
    android:layout_margin="16dp"
    android:padding="8dp"
    android:text="GPS: --"
    android:textColor="#FFFFFF"
    android:textSize="14sp"
    android:background="#80000000"
    android:fontFamily="monospace"/>
```

## Z-Order Considerations

### Ensuring Visibility
The indicator must be **above** all visualization content to remain visible.

**Android**: Add visualization views at index 0 to keep TextView on top:
```kotlin
rootLayout.addView(visualizationView, 0)  // Add at bottom of z-order
```

**iOS**: Place in ZStack after visualization content:
```swift
ZStack {
    VisualizationContent()  // Background
    GPSIndicatorOverlay()    // Foreground (rendered last = on top)
}
```

## Use Cases

### Development & Debugging
- **GPS Throttling Detection**: Quickly identify when system is throttling updates (red/orange colors)
- **Platform Comparison**: Compare update frequencies between iOS and Android
- **Algorithm Testing**: Verify location data is fresh when testing velocity calculations
- **Performance Profiling**: Monitor GPS behavior under different conditions (indoor/outdoor, moving/stationary)

### User Feedback
- **Signal Quality**: Users can see when GPS signal is weak or lost
- **Data Reliability**: Visual confirmation that displayed data is current
- **Troubleshooting**: Helps users understand if issues are GPS-related

## Testing Considerations

### Expected Behavior

| Scenario | Expected Display | Color |
|----------|-----------------|-------|
| App just started | `GPS: --` | Gray |
| Good GPS signal (outdoor, moving) | `GPS: now` or `GPS: 0.X-2.Xs` | Green |
| Indoor stationary | `GPS: 5.0-10.0s` | Orange |
| GPS disabled/lost | `GPS: 15.0+s` | Red |
| Using GPX playback | Updates with each GPX point | Green/Yellow |

### Cross-Platform Consistency
Both iOS and Android implementations should:
- Show identical text format
- Use identical color thresholds
- Update at same frequency (1 second)
- Calculate elapsed time identically

## Performance Impact

### Minimal Overhead
- **Timer frequency**: 1 Hz (low frequency)
- **Computation**: Simple timestamp subtraction and formatting
- **UI updates**: Single TextView/Text update per second
- **Memory**: Negligible (single timestamp + timer reference)

## Future Enhancements

Potential improvements:
1. **Configuration**: Allow users to toggle indicator on/off in settings
2. **Detailed Mode**: Show additional GPS metadata (accuracy, satellite count)
3. **History Graph**: Small sparkline showing update frequency over time
4. **Tap Interaction**: Tap to show detailed GPS status modal
5. **Positioning Options**: Let users choose indicator corner (top-left, top-right, etc.)
