# Velocity Calculation Algorithm

## Overview
The velocity calculation determines which bucket (idle, easy, medium, or hard) the user is currently in based on their GPS speed and elevation change.

## Input
- **Current Location**: GPS coordinates (latitude, longitude, altitude, speed)
- **Previous Location**: GPS coordinates from the previous reading
- **Thresholds**: User-configured threshold values

## Process

### 1. Speed Conversion
GPS speed is typically provided in meters per second (m/s). Convert to the display unit (mph or km/h):

```
speedMph = speedMps / 0.44704
speedKph = speedMps / 0.27778
```

### 2. Elevation Direction
Determine if the user is going uphill or downhill:

```
elevationChange = currentAltitude - previousAltitude

if elevationChange < 0:
    direction = DOWNHILL
else:
    direction = UPHILL  // Flat or uphill both use uphill thresholds
```

### 3. Bucket Determination

#### For Downhill:
```
if speedMph >= downhillHardThreshold:
    bucket = DOWNHILL_HARD
else if speedMph >= downhillMediumThreshold:
    bucket = DOWNHILL_MEDIUM
else if speedMph >= downhillEasyThreshold:
    bucket = DOWNHILL_EASY
else:
    bucket = IDLE
```

#### For Uphill:
```
if speedMph >= uphillHardThreshold:
    bucket = UPHILL_HARD
else if speedMph >= uphillMediumThreshold:
    bucket = UPHILL_MEDIUM
else if speedMph >= uphillEasyThreshold:
    bucket = UPHILL_EASY
else:
    bucket = IDLE
```

## Color Interpolation (for Colors visualization style)

When transitioning between buckets, calculate an interpolation factor for smooth color transitions:

```
interpolationFactor = (currentSpeed - lowerThreshold) / (upperThreshold - lowerThreshold)
interpolationFactor = clamp(interpolationFactor, 0.0, 1.0)
```

### Example: Transitioning from Medium to Hard
If speed is 8 mph, medium threshold is 6 mph, and hard threshold is 10 mph:
```
factor = (8 - 6) / (10 - 6) = 0.5
color = lerp(yellowColor, redColor, 0.5) = orange
```

## Edge Cases

1. **First Reading**: If there's no previous location, return IDLE
2. **Invalid Speed**: If speed is negative or unrealistic (> 100 mph), return IDLE
3. **Equal Thresholds**: Should never occur due to UI constraints, but if it does, use the lower bucket

## Implementation Notes

### iOS (Swift)
- Location: `Utilities/VelocityCalculator.swift`
- Method: `calculateBucket(currentLocation:previousLocation:)`
- Uses Float for all calculations

### Android (Kotlin)
- Location: `util/VelocityCalculator.kt`
- Method: `calculateBucket(currentLocation, previousLocation)`
- Uses Float for all calculations

Both implementations must produce identical results for the same inputs.
