# GPS Point Optimization

## Overview

When tracking GPS points every second, the number of points can grow very large over time, especially during periods when the user is stationary (e.g., waiting at a ski lift, taking a break). This algorithm removes redundant stationary points to reduce GPX file size while preserving timing information about when the user stopped and started moving.

## Problem

Without optimization:
- Recording at 1 Hz (1 point per second) for a 2-hour session = 7,200 points
- If the user is stationary for 10 minutes at a lift = 600 identical points
- Most of these points provide no useful information since lat/lon don't change
- Larger file sizes make sharing and processing slower

## Solution

Remove the middle point when three consecutive points have identical lat/lon coordinates.

### Algorithm

When receiving a new GPS point:

1. Check if we have at least 2 previous points stored
2. Compare the lat/lon of:
   - Current point (C)
   - Previous point (B)
   - Second previous point (A)
3. If all three points have **identical** lat/lon:
   - Remove point B from the GPX file
   - Keep point A (marks when we stopped moving)
   - Keep point C (current position, might start moving next)
4. Add the current point to the GPX file

### Why This Works

For a stationary period:
```
Point 1: (40.000, -105.000) at 10:00:00 ← KEPT (marks start of stop)
Point 2: (40.000, -105.000) at 10:00:01 ← KEPT (might move next)
Point 3: (40.000, -105.000) at 10:00:02 ← KEPT (point 2 removed, point 3 is new current)
Point 4: (40.000, -105.000) at 10:00:03 ← KEPT (point 3 removed, point 4 is new current)
...
Point N: (40.000, -105.000) at 10:10:00 ← KEPT (still at same location)
Point N+1: (40.010, -105.005) at 10:10:01 ← KEPT (movement detected)
```

Result in GPX file:
```
Point 1: (40.000, -105.000) at 10:00:00
Point N+1: (40.010, -105.005) at 10:10:01
```

We preserve:
- The timestamp when we stopped (Point 1)
- The timestamp when we started moving (Point N+1)
- The duration of the stationary period (10:10:01 - 10:00:00 = 10 minutes 1 second)

## Implementation Details

### Data Structures

Both platforms maintain:
- `previousLocation`: The last point added to the GPX file
- `secondPreviousLocation`: The point before that

### Comparison Logic

Two GPS points are considered identical if:
```
location1.latitude == location2.latitude &&
location1.longitude == location2.longitude
```

Note: We compare **exact** equality, not proximity. GPS coordinates at rest should be identical or very close.

### File Manipulation

When removing a redundant point:

1. Read the current GPX file content
2. Remove the closing XML tags (`</trkseg>`, `</trk>`, `</gpx>`)
3. Find the last `<trkpt>...</trkpt>` block
4. Remove that block entirely
5. Add the new point
6. Re-add the closing XML tags

### Edge Cases

1. **First two points**: Never removed (need 3 points to detect pattern)
2. **Alternating locations**: If user is on the edge of GPS precision and coordinates alternate, no removal occurs
3. **Altitude changes**: Ignored for this optimization (only lat/lon matter for "stationary" detection)
4. **Statistics**: Still calculated correctly since we update stats before updating location history

## Platform Implementation

### iOS: `GpxWriter.swift`

Located in: `iOS/SnowTeeth/Utilities/GpxWriter.swift`

```swift
// Track last two locations
private var previousLocation: LocationData?
private var secondPreviousLocation: LocationData?

func appendPoint(location: LocationData) throws {
    // Check if we should remove the previous point
    let shouldRemovePrevious = previousLocation != nil &&
                               secondPreviousLocation != nil &&
                               location.latitude == previousLocation!.latitude &&
                               location.longitude == previousLocation!.longitude &&
                               previousLocation!.latitude == secondPreviousLocation!.latitude &&
                               previousLocation!.longitude == secondPreviousLocation!.longitude

    // ... calculate statistics ...

    // Update location history
    secondPreviousLocation = previousLocation
    previousLocation = location

    // ... read GPX content ...

    // Remove last trkpt block if needed
    if shouldRemovePrevious {
        if let lastTrkptStart = content.range(of: "<trkpt", options: .backwards)?.lowerBound {
            if let lastTrkptEnd = content.range(of: "</trkpt>", options: [], range: lastTrkptStart..<content.endIndex)?.upperBound {
                content = String(content[..<lastTrkptStart]) + String(content[lastTrkptEnd...])
                content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    // ... add new point ...
}
```

### Android: `GpxWriter.kt`

Located in: `android/app/src/main/java/com/snowteeth/app/util/GpxWriter.kt`

```kotlin
// Track last two locations
private var previousLocation: LocationData? = null
private var secondPreviousLocation: LocationData? = null

fun appendPoint(location: LocationData) {
    // Check if we should remove the previous point
    val shouldRemovePrevious = previousLocation != null &&
                               secondPreviousLocation != null &&
                               location.latitude == previousLocation!!.latitude &&
                               location.longitude == previousLocation!!.longitude &&
                               previousLocation!!.latitude == secondPreviousLocation!!.latitude &&
                               previousLocation!!.longitude == secondPreviousLocation!!.longitude

    // ... calculate statistics ...

    // Update location history
    secondPreviousLocation = previousLocation
    previousLocation = location

    // ... read GPX content ...

    // Remove last trkpt block if needed
    if (shouldRemovePrevious) {
        val lastTrkptStart = content.lastIndexOf("<trkpt")
        if (lastTrkptStart >= 0) {
            val lastTrkptEnd = content.indexOf("</trkpt>", lastTrkptStart)
            if (lastTrkptEnd >= 0) {
                content = content.substring(0, lastTrkptStart) +
                         content.substring(lastTrkptEnd + "</trkpt>".length)
                content = content.trimEnd()
            }
        }
    }

    // ... add new point ...
}
```

## Performance Impact

### File Size Reduction

Example for a 2-hour ski session:
- Total time: 7,200 seconds
- Moving time: 1 hour (3,600 points)
- Stationary time: 1 hour (3,600 points)

Without optimization:
- Total points: 7,200
- File size: ~1.4 MB (assuming ~200 bytes per point)

With optimization:
- Moving points: 3,600
- Stationary periods reduced to ~10 points (assuming 6 stops of 10 minutes each)
- Total points: ~3,610
- File size: ~700 KB

**Result: ~50% file size reduction**

### Processing Overhead

- Adds 3 equality comparisons per point (negligible)
- When removing a point: one string search operation (rare, only when stationary)
- Overall performance impact: minimal

### Memory Usage

- Two additional LocationData objects stored: ~100 bytes
- Negligible impact on memory

## Testing

### Test Scenarios

1. **All moving**: No points removed
   ```
   Input:  [(40.0, -105.0), (40.1, -105.1), (40.2, -105.2)]
   Output: [(40.0, -105.0), (40.1, -105.1), (40.2, -105.2)]
   ```

2. **Three stationary points**: Middle removed
   ```
   Input:  [(40.0, -105.0), (40.0, -105.0), (40.0, -105.0)]
   Output: [(40.0, -105.0), (40.0, -105.0)]
   ```

3. **Long stationary period**: All middle points removed
   ```
   Input:  [(40.0, -105.0), (40.0, -105.0), (40.0, -105.0), (40.0, -105.0), (40.0, -105.0)]
   Output: [(40.0, -105.0), (40.0, -105.0)]
   ```

4. **Stop then move**: Stationary points compressed, movement preserved
   ```
   Input:  [(40.0, -105.0), (40.0, -105.0), (40.0, -105.0), (40.1, -105.1)]
   Output: [(40.0, -105.0), (40.0, -105.0), (40.1, -105.1)]
   ```

5. **Alternating locations**: No removal (not truly stationary)
   ```
   Input:  [(40.0, -105.0), (40.0, -105.0), (40.0001, -105.0001)]
   Output: [(40.0, -105.0), (40.0, -105.0), (40.0001, -105.0001)]
   ```

### Verification

To verify the optimization is working:

1. Start tracking
2. Stay stationary for 5 minutes
3. Stop tracking
4. Open the GPX file
5. Count `<trkpt>` entries - should be approximately 2 (start and end of stationary period)

## Future Enhancements

Potential improvements:

1. **Proximity-based removal**: Remove points within a small radius (e.g., 5 meters) instead of exact equality
   - More aggressive compression
   - Risk: might remove slow movement like walking

2. **Altitude consideration**: Consider elevation changes when determining "stationary"
   - More accurate for ski lifts (moving vertically)
   - Risk: altitude can be noisy

3. **Smart resumption**: When movement resumes, keep a few transitional points
   - Better track visualization
   - Risk: less compression

## Related Documentation

- [GPS Data Models](../models/data_models.md) - LocationData structure
- [Stats Calculation](stats_calculation.md) - How statistics are computed from GPS points
- [Velocity Smoothing](velocity_smoothing.md) - How GPS noise is filtered

## Version History

### v1.0.0 (2025-10-31)
- Initial implementation
- Exact lat/lon equality comparison
- Removes middle point of three identical consecutive points
