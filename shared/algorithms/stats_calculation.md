# Stats Calculation Algorithm

## Overview
Calculate statistics from the recorded GPX track data including vertical gain/loss, distance, average pace, and loop detection.

## Input
- **GPX Track Points**: Array of GPS coordinates with timestamps, elevations, and speeds

## Calculations

### 1. Cumulative Vertical Gain
Sum all positive elevation changes:

```
verticalGain = 0
for each consecutive point pair (prev, current):
    elevationChange = current.altitude - prev.altitude
    if elevationChange > 0:
        verticalGain += elevationChange
```

### 2. Cumulative Vertical Loss
Sum all negative elevation changes (as positive value):

```
verticalLoss = 0
for each consecutive point pair (prev, current):
    elevationChange = current.altitude - prev.altitude
    if elevationChange < 0:
        verticalLoss += abs(elevationChange)
```

### 3. Horizontal Distance
Use Haversine formula for great-circle distance between GPS points:

```
function haversineDistance(lat1, lon1, lat2, lon2):
    R = 6371000  // Earth radius in meters

    φ1 = lat1 * π / 180
    φ2 = lat2 * π / 180
    Δφ = (lat2 - lat1) * π / 180
    Δλ = (lon2 - lon1) * π / 180

    a = sin²(Δφ/2) + cos(φ1) * cos(φ2) * sin²(Δλ/2)
    c = 2 * atan2(√a, √(1-a))

    distance = R * c  // in meters
    return distance

totalDistance = 0
for each consecutive point pair:
    totalDistance += haversineDistance(prev.lat, prev.lon, current.lat, current.lon)
```

Convert to display units:
```
distanceMiles = totalDistance / 1609.34
distanceKm = totalDistance / 1000
```

### 4. Average Downhill Pace
Calculate average velocity during downhill segments **while moving**:

```
MINIMUM_MOVING_SPEED = 0.5  // m/s (≈ 1.1 mph ≈ 1.8 km/h)

downhillVelocitySum = 0  // m/s
downhillMovingPointCount = 0

for each point:
    elevationChange = current.altitude - prev.altitude

    if elevationChange < 0:
        // Downhill segment
        downhillDistance += haversineDistance(prev, current)

        // Only include in average if actually moving (excludes stops)
        if current.speed > MINIMUM_MOVING_SPEED:
            downhillVelocitySum += current.speed
            downhillMovingPointCount += 1

// Calculate average velocity from moving points only
avgDownhillVelocityMPS = downhillMovingPointCount > 0 ? downhillVelocitySum / downhillMovingPointCount : 0

// Convert m/s to display units
avgDownhillPaceMPH = avgDownhillVelocityMPS * 2.23694
avgDownhillPaceKPH = avgDownhillVelocityMPS * 3.6
```

**Important**: The average only includes points where `speed > 0.5 m/s`. This excludes:
- Stationary periods (waiting at lifts, rest breaks)
- Very slow movement (< 1.1 mph)
- Result: Average represents speed **while actively moving** downhill

### 5. Average Uphill Pace
Calculate average velocity during uphill and flat segments **while moving**:

```
MINIMUM_MOVING_SPEED = 0.5  // m/s (≈ 1.1 mph ≈ 1.8 km/h)

uphillVelocitySum = 0  // m/s
uphillMovingPointCount = 0

for each point:
    elevationChange = current.altitude - prev.altitude

    if elevationChange >= 0:
        // Uphill or flat segment
        uphillDistance += haversineDistance(prev, current)

        // Only include in average if actually moving (excludes stops)
        if current.speed > MINIMUM_MOVING_SPEED:
            uphillVelocitySum += current.speed
            uphillMovingPointCount += 1

// Calculate average velocity from moving points only
avgUphillVelocityMPS = uphillMovingPointCount > 0 ? uphillVelocitySum / uphillMovingPointCount : 0

// Convert m/s to display units
avgUphillPaceMPH = avgUphillVelocityMPS * 2.23694
avgUphillPaceKPH = avgUphillVelocityMPS * 3.6
```

### 6. Moving Time Calculation
Calculate the total time spent in motion (excludes stopped/stationary periods):

```
MOVING_SPEED_THRESHOLD = 1.0  // mph (or 1.6 km/h if metric)

movingTimeSeconds = 0

for each consecutive point pair (prev, current):
    timeDelta = (current.timestamp - prev.timestamp) / 1000  // Convert ms to seconds

    // Calculate instantaneous speed for this segment
    segmentDistance = haversineDistance(prev, current)  // meters
    instantaneousSpeed = segmentDistance / timeDelta    // m/s

    // Convert to display units
    speedMPH = instantaneousSpeed * 2.23694
    speedKPH = instantaneousSpeed * 3.6

    // Check if moving (use appropriate threshold based on useMetric)
    isMoving = (useMetric ? speedKPH : speedMPH) > MOVING_SPEED_THRESHOLD

    if isMoving:
        movingTimeSeconds += timeDelta
```

**Rationale**:
- **Moving time** is a universal metric that works across all sports (skiing, running, cycling, rowing)
- Excludes lift rides (stationary or very slow), rest breaks, and GPS drift while stopped
- More useful than loop counting, which has different meanings across different sports

## Constants

```json
{
  "earthRadiusMeters": 6371000,
  "metersPerMile": 1609.34,
  "metersPerKm": 1000,
  "feetPerMeter": 3.28084,
  "mpsToMph": 2.23694,
  "mpsToKph": 3.6,
  "movingSpeedThresholdMPH": 1.0,
  "movingSpeedThresholdKPH": 1.6
}
```

## Return Data

The `TrackStats` structure returned by the calculator contains:

```
struct TrackStats {
    verticalFeetUp: Double       // Cumulative vertical gain in feet
    verticalFeetDown: Double     // Cumulative vertical loss in feet
    horizontalDistance: Double   // Total distance in miles (or km if metric)
    avgDownhillPace: Double      // Average downhill velocity in mph (or km/h if metric)
    avgUphillPace: Double        // Average uphill velocity in mph (or km/h if metric)
    movingTimeSeconds: Double    // Total time spent moving (seconds)
}
```

Note:
- Vertical values are always in feet regardless of metric setting. Convert to meters by dividing by 3.28084.
- Moving time should be formatted as HH:MM:SS for display

## Implementation Notes

### iOS (Swift)
- Location: `Utilities/StatsCalculator.swift`
- Method: `calculateStats(points:useMetric:) -> TrackStats`

### Android (Kotlin)
- Location: `util/StatsCalculator.kt`
- Method: `calculateStats(points, useMetric): TrackStats`

Both implementations must produce identical results for the same GPX data.

### Time Formatting Helper

Both platforms should provide a helper function to format moving time:

```
func formatTime(seconds: Double) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60

    // Always show hours for clarity (H:MM:SS format)
    return String(format: "%d:%02d:%02d", hours, minutes, secs)
}
```
