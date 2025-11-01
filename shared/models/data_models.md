# SnowTeeth Data Models

## Core Data Structures

### VelocityBucket

Represents the current activity level based on speed and elevation.

```
enum VelocityBucket {
    IDLE,
    DOWNHILL_EASY,
    DOWNHILL_MEDIUM,
    DOWNHILL_HARD,
    UPHILL_EASY,
    UPHILL_MEDIUM,
    UPHILL_HARD
}
```

**Usage**: Determines visualization and statistics categorization

---

### LocationData

GPS location data point.

```
struct LocationData {
    latitude: Double       // Degrees
    longitude: Double      // Degrees
    altitude: Double       // Meters above sea level
    speed: Float          // Meters per second
    timestamp: DateTime   // When this point was recorded
    horizontalAccuracy: Double?  // Optional accuracy in meters
    verticalAccuracy: Double?    // Optional accuracy in meters
}
```

**Notes**:
- Speed is from GPS, not calculated
- Accuracy fields help filter bad data points
- Timestamp used for GPX export

---

### VisualizationStyle

Display mode for real-time feedback.

```
enum VisualizationStyle {
    FLAME,    // Volumetric raymarched fire effect with parametric presets
    DATA,     // GPS data display with animated character morphing
    YETI      // State-based video playback synchronized to velocity buckets
}
```

---

### AppPreferences

User settings persisted across sessions.

```
struct AppPreferences {
    // Thresholds (in mph)
    downhillEasyThreshold: Float     // Default: 2.0
    downhillMediumThreshold: Float   // Default: 6.0
    downhillHardThreshold: Float     // Default: 10.0
    uphillEasyThreshold: Float       // Default: 1.0
    uphillMediumThreshold: Float     // Default: 3.0
    uphillHardThreshold: Float       // Default: 5.0

    // Settings
    useMetric: Boolean               // Default: false (use mph/feet)
    visualizationStyle: VisualizationStyle  // Default: FLAME
    isTracking: Boolean              // Current tracking state
}
```

**Constraints**:
- All thresholds must be positive
- Downhill: hard > medium > easy (with min 0.5 gap)
- Uphill: hard > medium > easy (with min 0.5 gap)
- Uphill and downhill thresholds are independent

---

### TrackStats

Calculated statistics from a tracking session.

```
struct TrackStats {
    verticalFeetUp: Double          // Cumulative upward elevation (always in feet)
    verticalFeetDown: Double        // Cumulative downward elevation (always in feet)
    horizontalDistance: Double      // Total horizontal distance (miles or km based on useMetric)
    avgDownhillPace: Double         // Average downhill velocity (mph or km/h based on useMetric)
    avgUphillPace: Double           // Average uphill velocity (mph or km/h based on useMetric)
    movingTimeSeconds: Double       // Total time spent moving (seconds)
}
```

**Display**:
- Vertical values are always in feet regardless of `useMetric` setting
- Convert feet to meters for display: divide by 3.28084
- `horizontalDistance`, `avgDownhillPace`, and `avgUphillPace` are already in the correct units based on `useMetric` parameter passed to `calculateStats()`
- `movingTimeSeconds` should be formatted as HH:MM:SS for display

---

## File Formats

### GPX Track File

Standard GPX 1.1 format for storing GPS tracks.

**File Location**:
- iOS: App's Documents directory
- Android: App's internal storage

**File Naming**: `snowteeth_YYYYMMDD_HHMMSS.gpx`

**Structure**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1"
     creator="SnowTeeth"
     xmlns="http://www.topografix.com/GPX/1/1">
  <trk>
    <name>SnowTeeth Track</name>
    <trkseg>
      <trkpt lat="37.123456" lon="-122.123456">
        <ele>1234.5</ele>
        <time>2024-10-27T19:30:00Z</time>
      </trkpt>
      <!-- More track points... -->
    </trkseg>
  </trk>
</gpx>
```

**Recording Rules**:
- GPS sampled every 1 second
- GPX point written every 10 seconds (to reduce file size)
- Altitude in meters
- Time in ISO 8601 UTC format

---

## Implementation Mapping

### iOS (Swift)
```
VelocityBucket     -> Models/VelocityBucket.swift (enum)
LocationData       -> Models/LocationData.swift (struct)
VisualizationStyle -> Models/VisualizationStyle.swift (enum)
AppPreferences     -> Utilities/AppPreferences.swift (class, ObservableObject)
TrackStats         -> StatsCalculator.swift (struct, return type)
```

### Android (Kotlin)
```
VelocityBucket     -> model/VelocityBucket.kt (enum class)
LocationData       -> model/LocationData.kt (data class)
VisualizationStyle -> model/VisualizationStyle.kt (enum class)
AppPreferences     -> util/AppPreferences.kt (class)
TrackStats         -> StatsCalculator.kt (data class, return type)
```

---

## Type Conversions

| Shared Type | iOS Type | Android Type |
|-------------|----------|--------------|
| Float       | Float    | Float        |
| Double      | Double   | Double       |
| Boolean     | Bool     | Boolean      |
| DateTime    | Date     | Date         |
| TimeInterval| TimeInterval | Long (milliseconds) |

---

## Validation Rules

### Thresholds
- Must be positive (> 0)
- Must maintain ordering with minimum 0.5 gap
- Within slider ranges (see `thresholds.json`)

### Location Data
- Latitude: -90 to 90
- Longitude: -180 to 180
- Speed: >= 0
- Altitude: any reasonable value (-500 to 9000 meters)

### GPS Data Quality
- Ignore points with horizontal accuracy > 50 meters
- Ignore points with speed > 100 mph (likely GPS error)
- Ignore altitude changes > 100 meters between consecutive 1-second readings
