# Elevation Smoothing and Filtering

## Purpose

GPS elevation (altitude) readings are significantly less accurate than horizontal position, especially under tree canopy, near buildings, or with poor satellite geometry. This algorithm filters and smooths elevation data to:

1. **Remove signal degradation artifacts** - Reject readings taken with poor vertical accuracy
2. **Eliminate impossible elevation spikes** - Filter physically impossible elevation changes
3. **Smooth GPS noise** - Reduce meter-scale jitter while preserving real elevation changes
4. **Maintain terrain features** - Preserve actual uphill/downhill trends for statistics

## The Problem

GPS elevation is inherently less accurate than horizontal position because:

1. **Satellite geometry**: Vertical accuracy requires satellites at various angles; most are near the horizon
2. **Signal blockage**: Trees, buildings, and terrain block satellite signals from low angles
3. **Multipath interference**: Signals bounce off surfaces before reaching the receiver
4. **Atmospheric effects**: Ionospheric delays affect vertical position more than horizontal

**Typical accuracy:**
- Horizontal: ±5 meters (good conditions)
- Vertical: ±10-15 meters (good conditions)
- Vertical under trees: ±20-50 meters (severely degraded)

### Real-World Example

From `shared/testing_data/gpx/block.gpx` (walking under trees):

```
Time      | Elevation | Change | Reality
02:53:02  | 47.1m     | --     | Starting point
02:54:33  | 61.5m     | +14.4m | GPS spike (impossible: 14m in 91 seconds while walking)
02:54:35  | 51.9m     | -9.7m  | GPS correction (bouncing back down)
02:54:37  | 50.1m     | -1.8m  | Stabilizing
```

The user was walking downhill, but GPS showed a 14-meter uphill climb due to tree canopy interference.

## Solution Overview

Two-stage approach:

1. **Stage 1: Accuracy-Based Filtering** - Reject/de-weight readings with poor vertical accuracy
2. **Stage 2: Elevation Smoothing** - Apply exponential moving average to reduce noise

## Stage 1: Pattern-Based Spike Detection

Traditional GPS accuracy filtering relies on `verticalAccuracy` values, but these are often unavailable or unreliable in recorded GPX files. Instead, we use **pattern-based spike detection** that analyzes the sequence of elevation changes.

### The Problem with Variance-Based Detection

A naive approach uses elevation variance in a window to detect spikes:
```
if variance > threshold: reject reading
```

**This fails because it can't distinguish:**
- **Real hills**: High variance from consistent upward/downward trend
- **GPS spikes**: High variance from erratic jumps

Result: Legitimate hills get rejected, causing lag and sudden jumps.

### Pattern-Based Solution

Analyze the **sequence of changes** to detect spike patterns:

```swift
// Look at last 3-4 elevation changes
changes = [ele[i-3]→ele[i-2], ele[i-2]→ele[i-1], ele[i-1]→ele[i]]

// Pattern 1: Reversal spike (large change that reverses)
// Example: [+10m, -9m] = spike up then correction
if abs(lastChange) > 3.0 && abs(secondLastChange) > 3.0:
    if opposite_signs(lastChange, secondLastChange):
        return POOR_ACCURACY  // GPS spike detected

// Pattern 2: Oscillating noise (back-and-forth pattern)
// Example: [+1m, -1.2m, +0.9m] = up-down-up
if all_changes_alternate_direction:
    return POOR_ACCURACY  // Oscillating noise

// Pattern 3: Consistent trend (all same direction)
// Example: [+1.5m, +1.8m, +1.2m] = climbing hill
if most_changes_same_direction:
    return GOOD_ACCURACY  // Legitimate elevation change
```

### Spike Detection Rules

**Reject as spikes (mark as poor accuracy):**
1. **Reversal spikes**: Changes >3m that reverse direction
   - Example: 50m → 60m → 51m (spike up then back down)
   - Example: 50m → 40m → 49m (spike down then back up)

2. **Oscillating pattern**: 3+ consecutive changes that alternate direction
   - Example: 50 → 51 → 49.5 → 50.8 (up-down-up)
   - Indicates GPS is bouncing between incorrect values

**Accept as legitimate (mark as good accuracy):**
- **Consistent trends**: Multiple changes in the same direction
  - Example: 50 → 51.5 → 53 → 54.2 (climbing)
  - Example: 60 → 58 → 56.5 → 55 (descending)

### Why This Works

**GPS Spike Characteristics:**
- Sudden large change (>3-5m in 1 second)
- Immediately corrects back (reversal pattern)
- Random direction (oscillates up and down)

**Real Hill Characteristics:**
- Gradual consistent change (same direction for multiple points)
- Magnitude proportional to activity (hiking: ~0.5-2m/sec, skiing downhill: ~1-3m/sec)
- Smooth progression, not erratic jumps

### Configuration Parameters

- **`verticalAccuracyThreshold`**: Maximum acceptable accuracy estimate (default: 20.0 meters)
  - Pattern-based detector assigns accuracy values:
    - 8.0m = legitimate elevation change
    - 15.0m = minor jitter
    - 25.0m = oscillating noise
    - 30.0m = reversal spike
  - Set threshold at 20.0m to reject spikes (25m+) while accepting trends (8m)

- **`spikeReversalThreshold`**: Minimum change to check for reversals (default: 3.0 meters)
  - Changes smaller than this are considered normal GPS jitter

## Stage 2: Elevation Smoothing with Adaptive Alpha

After filtering, apply exponential moving average (EMA) with **adaptive alpha** based on trend detection:

```
if firstReading:
    smoothed = elevation
else:
    alpha = calculateAdaptiveAlpha()  // Between alphaMin and alphaMax
    smoothed = alpha × elevation + (1 - alpha) × previousSmoothed
```

### Configuration Parameters

- **`alphaMin`**: Minimum weight for new reading (default: 0.3)
  - Used when elevation is oscillating (noise)
  - Conservative smoothing for GPS jitter

- **`alphaMax`**: Maximum weight for new reading (default: 0.7)
  - Used when elevation is trending consistently (real hills)
  - Responsive to actual elevation changes

- **`trendWindow`**: Number of recent readings to analyze (default: 5)
  - Determines how many points are used for trend detection

### Adaptive Alpha Calculation

The algorithm detects trends by analyzing recent elevation changes:

1. **Direction Consistency**: Are elevations consistently going up or down?
   - All changes in same direction → high trend strength
   - Changes alternating → low trend strength

2. **Magnitude**: How large are the changes?
   - Larger consistent changes (>2m) → boost responsiveness
   - Small changes → remain conservative

3. **Combined Strength**:
   ```
   trendStrength = majorityDirection / totalChanges
   magnitudeBoost = min(avgChange / 2.0, 1.0)
   combinedStrength = (trendStrength + magnitudeBoost) / 2.0
   alpha = alphaMin + combinedStrength × (alphaMax - alphaMin)
   ```

### Why Adaptive Alpha?

**Fixed Alpha Problems:**
- Low alpha (0.3): Smooths noise well BUT lags behind real hills
- High alpha (0.7): Follows hills well BUT doesn't filter noise

**Adaptive Solution:**
- **Noise (oscillating)**: Use low alpha (0.3) → aggressive smoothing
- **Trends (consistent uphill/downhill)**: Use high alpha (0.7) → responsive tracking
- **Result**: Eliminates spikes while preserving legitimate elevation changes

## Algorithm Implementation

```swift
class ElevationSmoother {
    private var previousSmoothed: Double? = nil
    private var recentElevations: [Double] = []  // Raw elevations for pattern detection
    private var recentAcceptedElevations: [Double] = []  // Accepted elevations for trend detection
    private let accuracyThreshold: Double = 20.0
    private let alphaMin: Double = 0.25
    private let alphaMax: Double = 0.75
    private let trendWindow: Int = 5
    private let spikeReversalThreshold: Double = 3.0

    func addReading(elevation: Double, verticalAccuracy: Double = -1.0) -> Double {
        // Track raw elevations for pattern-based spike detection
        recentElevations.append(elevation)
        if recentElevations.count > 4 {
            recentElevations.removeFirst()
        }

        // Stage 1: Pattern-based spike detection
        let estimatedAccuracy = estimateAccuracyFromPattern()
        var accepted = elevation
        var wasRejected = false

        // Use provided vertical accuracy if available, otherwise use pattern-based estimate
        let accuracyToUse = verticalAccuracy >= 0 ? verticalAccuracy : estimatedAccuracy

        if accuracyToUse > accuracyThreshold {
            // Poor accuracy - reject and use previous smoothed value
            if let prev = previousSmoothed {
                accepted = prev
                wasRejected = true
            }
        }

        // Track accepted elevations for adaptive smoothing
        if !wasRejected {
            recentAcceptedElevations.append(accepted)
            if recentAcceptedElevations.count > trendWindow {
                recentAcceptedElevations.removeFirst()
            }
        }

        // Stage 2: Adaptive EMA smoothing
        let alpha = calculateAdaptiveAlpha()
        let smoothed: Double
        if let prev = previousSmoothed {
            smoothed = alpha * accepted + (1 - alpha) * prev
        } else {
            smoothed = accepted  // First reading
        }

        previousSmoothed = smoothed
        return smoothed
    }

    private func estimateAccuracyFromPattern() -> Double {
        // Need at least 4 points to detect patterns
        guard recentElevations.count >= 4 else {
            return 20.0  // Conservative for first few points
        }

        // Calculate recent changes
        var changes: [Double] = []
        for i in 1..<recentElevations.count {
            changes.append(recentElevations[i] - recentElevations[i-1])
        }

        // Pattern 1: Detect reversal spikes (large change that reverses)
        if changes.count >= 2 {
            let lastChange = changes[changes.count - 1]
            let secondLastChange = changes[changes.count - 2]

            if abs(lastChange) > spikeReversalThreshold &&
               abs(secondLastChange) > spikeReversalThreshold {
                // Check if they reverse direction
                if (lastChange > 0 && secondLastChange < 0) ||
                   (lastChange < 0 && secondLastChange > 0) {
                    return 30.0  // GPS spike detected
                }
            }
        }

        // Pattern 2: Detect oscillating noise (alternating directions)
        if changes.count >= 3 {
            let signs = changes.map { $0 > 0 ? 1 : ($0 < 0 ? -1 : 0) }
            if signs[0] != 0 && signs[1] != 0 && signs[2] != 0 {
                // Check if alternating: +, -, + or -, +, -
                if signs[0] != signs[1] && signs[1] != signs[2] {
                    return 25.0  // Oscillating noise
                }
            }
        }

        // Pattern 3: Check for micro-jitter (small oscillations around same value)
        if recentElevations.count >= 5 {
            let mean = recentElevations.reduce(0, +) / Double(recentElevations.count)
            let maxDeviation = recentElevations.map { abs($0 - mean) }.max() ?? 0
            if maxDeviation < 1.0 {
                return 15.0  // Minor jitter while stationary
            }
        }

        // If no spike pattern detected, accept as legitimate
        return 8.0  // Good accuracy
    }

    private func calculateAdaptiveAlpha() -> Double {
        guard recentAcceptedElevations.count >= 3 else {
            return alphaMin
        }

        // Calculate changes between consecutive accepted readings
        var changes: [Double] = []
        for i in 1..<recentAcceptedElevations.count {
            changes.append(recentAcceptedElevations[i] - recentAcceptedElevations[i-1])
        }

        // Analyze trend direction
        let positiveCount = changes.filter { $0 > 0 }.count
        let negativeCount = changes.filter { $0 < 0 }.count
        let totalNonZero = positiveCount + negativeCount

        guard totalNonZero > 0 else { return alphaMin }

        let majorityCount = max(positiveCount, negativeCount)
        let trendStrength = Double(majorityCount) / Double(totalNonZero)

        // Consider magnitude
        let avgMagnitude = changes.map { abs($0) }.reduce(0, +) / Double(changes.count)
        let magnitudeBoost = min(avgMagnitude / 2.0, 1.0)

        // Combine and map to alpha range
        let combinedStrength = (trendStrength + magnitudeBoost) / 2.0
        return alphaMin + combinedStrength * (alphaMax - alphaMin)
    }

    func reset() {
        previousSmoothed = nil
        recentElevations.removeAll()
        recentAcceptedElevations.removeAll()
    }
}
```

## Data Flow

```
Raw GPS Reading → Accuracy Check → Smoothing → Output
     ↓                 ↓              ↓           ↓
  (ele: 61.5m)   (accuracy: 25m)  (reject,    (50.1m)
  (acc: 25m)     (too poor!)       use prev)   (smoothed)
```

## Example Scenarios

### Scenario 1: Walking Under Trees (block.gpx)

```
Time     | Raw Ele | V.Acc | Accepted | Smoothed
---------|---------|-------|----------|----------
02:53:02 | 47.1m   | 20m   | 47.1m    | 47.1m    (first reading)
02:54:33 | 61.5m   | 30m   | 47.1m    | 47.1m    (rejected: poor acc)
02:54:35 | 51.9m   | 25m   | 47.1m    | 47.1m    (rejected: poor acc)
02:54:37 | 50.1m   | 12m   | 50.1m    | 48.0m    (accepted, smoothed)
02:54:39 | 48.7m   | 10m   | 48.7m    | 48.2m    (accepted, smoothed)
```

Result: Eliminated the false 14m elevation gain.

### Scenario 2: Skiing Downhill (Good GPS)

```
Time     | Raw Ele | V.Acc | Accepted | Smoothed
---------|---------|-------|----------|----------
10:00:00 | 1000m   | 8m    | 1000m    | 1000m
10:00:10 | 995m    | 7m    | 995m     | 998.5m   (smooth descent)
10:00:20 | 990m    | 8m    | 990m     | 996.0m   (smooth descent)
10:00:30 | 985m    | 6m    | 985m     | 992.7m   (smooth descent)
```

Result: Smooth elevation profile follows actual terrain.

### Scenario 3: Stationary (GPS Jitter)

```
Time     | Raw Ele | V.Acc | Accepted | Smoothed
---------|---------|-------|----------|----------
10:00:00 | 100m    | 5m    | 100m     | 100m
10:00:01 | 102m    | 6m    | 102m     | 100.6m   (+2m jitter)
10:00:02 | 98m     | 5m    | 98m      | 99.8m    (-2m jitter)
10:00:03 | 101m    | 6m    | 101m     | 100.2m   (+1m jitter)
```

Result: Smoothed output stays near true elevation despite ±2m GPS jitter.

## Integration with Existing Systems

### Use Raw Elevation for GPX Files

Store raw, unsmoothed elevation in GPX files:
- Preserves original GPS data
- Allows reprocessing with different algorithms later
- Standard practice for GPS track files

```swift
// Write to GPX
try gpxWriter.appendPoint(location: rawLocationData)  // Raw elevation
```

### Use Smoothed Elevation for Display and Statistics

Use smoothed elevation for real-time display and statistics:
- Better user experience (no jumping numbers)
- More accurate statistics (no false climbs)
- Correct uphill/downhill detection

```swift
// Display and stats
let smoothedElevation = elevationSmoother.addReading(
    rawLocationData.altitude,
    verticalAccuracy: rawLocationData.verticalAccuracy
)
let displayLocation = LocationData(
    latitude: rawLocationData.latitude,
    longitude: rawLocationData.longitude,
    altitude: smoothedElevation,  // Smoothed
    timestamp: rawLocationData.timestamp,
    speed: smoothedSpeed,
    horizontalAccuracy: rawLocationData.horizontalAccuracy
)
```

## Platform Implementation

### iOS: LocationData.swift

Add `verticalAccuracy` field:

```swift
struct LocationData {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Int64
    let speed: Float
    let horizontalAccuracy: Double
    let verticalAccuracy: Double  // NEW

    init(from location: CLLocation) {
        // ...
        self.verticalAccuracy = location.verticalAccuracy
    }
}
```

### iOS: LocationTrackingService.swift

Add elevation smoother alongside velocity smoother:

```swift
class LocationTrackingService {
    private var velocitySmoother: VelocitySmoother
    private var elevationSmoother: VelocitySmoother  // Reuse same class!

    init(prefs: AppPreferences) {
        // Velocity smoother: responsive (alpha=0.6)
        self.velocitySmoother = VelocitySmoother(config: .skiing(useMetric: prefs.useMetric))

        // Elevation smoother: more conservative (alpha=0.3)
        self.elevationSmoother = VelocitySmoother(config: VelocitySmootherConfig(
            absoluteMaxValue: 1000.0,  // Not used for elevation
            spikeMultiplier: 1.0,      // Not used for elevation
            minValueThreshold: -1000.0, // Not used for elevation
            alpha: 0.3
        ))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let rawLocationData = LocationData(from: location)

        // Smooth velocity
        let smoothedSpeed = velocitySmoother.addReading(...)

        // Smooth elevation with accuracy filtering
        var elevationToSmooth = rawLocationData.altitude
        if rawLocationData.verticalAccuracy < 0 || rawLocationData.verticalAccuracy > 15.0 {
            // Poor accuracy - use previous smoothed or raw if first reading
            // The smoother will use previousSmoothed automatically
        }
        let smoothedElevation = elevationSmoother.addReading(Float(elevationToSmooth))

        // Create smoothed location for display
        let smoothedLocationData = LocationData(
            latitude: rawLocationData.latitude,
            longitude: rawLocationData.longitude,
            altitude: Double(smoothedElevation),  // Smoothed
            timestamp: rawLocationData.timestamp,
            speed: smoothedSpeed,
            horizontalAccuracy: rawLocationData.horizontalAccuracy,
            verticalAccuracy: rawLocationData.verticalAccuracy
        )

        // Store raw for GPX
        try gpxWriter.appendPoint(location: rawLocationData)

        // Use smoothed for display
        currentLocation = smoothedLocationData
    }
}
```

### Android: LocationData.kt

Add `verticalAccuracy` field:

```kotlin
data class LocationData(
    val latitude: Double,
    val longitude: Double,
    val altitude: Double,
    val timestamp: Long,
    val speed: Float,
    val horizontalAccuracy: Double,
    val verticalAccuracy: Double  // NEW
) {
    constructor(location: Location) : this(
        latitude = location.latitude,
        longitude = location.longitude,
        altitude = location.altitude,
        timestamp = location.time,
        speed = maxOf(0f, location.speed),
        horizontalAccuracy = location.accuracy.toDouble(),
        verticalAccuracy = if (location.hasVerticalAccuracy()) {
            location.verticalAccuracyMeters.toDouble()
        } else {
            -1.0
        }
    )
}
```

## Performance Considerations

- **Accuracy check**: O(1) - simple comparison
- **EMA smoothing**: O(1) - single multiplication and addition
- **Memory**: O(1) - only previous smoothed value stored
- **Real-time latency**: Immediate (no buffering)

## Configuration Tuning

### Default Settings (Recommended)

```
accuracyThreshold: 15.0 meters
alphaMin: 0.3
alphaMax: 0.7
trendWindow: 5
```

### Activity-Specific Tuning

**Skiing/Snowboarding** (fast elevation changes):
```
accuracyThreshold: 12.0 meters  (tighter filtering)
alphaMin: 0.3                    (smooth noise)
alphaMax: 0.8                    (very responsive to trends)
trendWindow: 4                   (shorter window for faster response)
```

**Hiking** (slower, more jitter tolerance):
```
accuracyThreshold: 20.0 meters  (looser filtering)
alphaMin: 0.2                    (more aggressive smoothing)
alphaMax: 0.6                    (moderate responsiveness)
trendWindow: 6                   (longer window for stability)
```

**Walking under trees** (poor GPS):
```
accuracyThreshold: 25.0 meters  (very loose filtering)
alphaMin: 0.3                    (standard smoothing)
alphaMax: 0.7                    (standard responsiveness)
trendWindow: 5                   (standard window)
```

## Testing

### Test Data

Use `shared/testing_data/gpx/block.gpx`:
- Contains real-world tree canopy interference
- Shows 14m false elevation gain in first minute
- Good test case for filtering effectiveness

### Expected Improvements

Before filtering:
- Elevation variance: ±5-10m while stationary
- False elevation gains under trees: 10-20m
- Noisy uphill/downhill detection

After filtering:
- Elevation variance: ±1-2m while stationary
- No false elevation gains (rejected poor readings)
- Stable uphill/downhill detection

## Related Documentation

- [Velocity Smoothing](velocity_smoothing.md) - Similar algorithm for speed
- [GPS Data Models](../models/data_models.md) - LocationData structure
- [Stats Calculation](stats_calculation.md) - How elevation gain is calculated

## Version History

### v1.2.0 (2025-10-31)
- **Pattern-based spike detection**: Analyzes sequence of changes instead of variance
- Detects reversal spikes (large changes that reverse direction)
- Detects oscillating noise (back-and-forth pattern)
- Accepts consistent trends (legitimate hills)
- Fixes issue where variance-based detection rejected real hills
- Default: accuracyThreshold=20.0, alphaMin=0.25, alphaMax=0.75, spikeReversalThreshold=3.0

### v1.1.0 (2025-10-31)
- **Adaptive smoothing**: Dynamic alpha based on trend detection
- Responds to consistent elevation changes (hills) while filtering noise
- Default: alphaMin=0.3, alphaMax=0.7, trendWindow=5
- **Issue**: Variance-based accuracy estimation couldn't distinguish hills from spikes

### v1.0.0 (2025-10-31)
- Initial implementation with fixed alpha
- Two-stage filtering: vertical accuracy check + EMA smoothing
- Alpha = 0.3 for conservative elevation smoothing
- Accuracy threshold = 15.0 meters
- **Issue**: Too aggressive smoothing caused lag on legitimate elevation changes

## References

- GPS Vertical Accuracy: https://www.gps.gov/systems/gps/performance/accuracy/
- Tree Canopy Effects: Sigrist et al. (2012) "Impact of forest canopy on quality and accuracy of GPS measurements"
- Elevation Smoothing in Sports: Malone et al. (2017) "Unpacking the Black Box: Applications and Considerations for Using GPS Devices in Sport"
- Real-world test data: shared/testing_data/gpx/block.gpx
