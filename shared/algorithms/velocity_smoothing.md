# Velocity Smoothing Algorithm

## Purpose

GPS velocity readings can contain occasional bursts of unrealistic values due to signal interference or GPS errors. This algorithm filters velocity data to:

1. **Remove impossible spikes** - Eliminate unrealistic velocity spikes caused by GPS errors
2. **Preserve stops** - Allow the system to detect when the user has actually stopped moving
3. **Maintain responsiveness** - React quickly to legitimate speed changes (critical for skiing/snowboarding)

## Design Philosophy

**Responsiveness over smoothness**: Skiing and snowboarding involve rapid, legitimate speed changes (0→20 mph in seconds). The algorithm must NOT treat these as outliers. We only filter physically impossible spikes while maintaining fast response to real changes.

## Algorithm Overview

The smoothing process uses lightweight spike rejection with exponential moving average:

1. **Simple Spike Rejection** - Reject only physically impossible values
2. **Exponential Moving Average** - Light smoothing that responds quickly to changes

## Stage 1: Spike Rejection

Simple rules to reject only physically impossible values:

```
if velocity < minValueThreshold:
    // Always preserve stops
    accept velocity
else if velocity > absoluteMaxValue AND velocity > spikeMultiplier × previousSmoothed:
    // Reject impossible spikes
    reject velocity, use previousSmoothed instead
else:
    // Accept as valid
    accept velocity
```

### Configuration Parameters

- **`absoluteMaxValue`**: Hard ceiling for realistic velocity
  - Example: 30 mph (48 km/h) for skiing/snowboarding
  - Values must exceed BOTH this AND the spike multiplier to be rejected

- **`spikeMultiplier`**: How many times previous value before rejecting (default: 3.0)
  - Example: if previous=10 mph, reject values > 30 mph
  - Allows legitimate rapid acceleration while catching GPS glitches

- **`minValueThreshold`**: Minimum movement speed
  - Example: 1.0 mph (1.6 km/h)
  - Values below this are always preserved (stops)

### Why This Works

**GPS spikes are characterized by:**
- Single-reading anomalies (spike then return to normal)
- Values that are impossibly high for the sport
- Sudden jumps that violate physics (e.g., 5 mph → 50 mph in 1 second)

**Legitimate speed changes are characterized by:**
- Sustained changes over multiple readings
- Values within realistic bounds
- Gradual acceleration/deceleration (even if rapid)

By requiring BOTH conditions (> absoluteMax AND > spikeMultiplier × previous), we only reject clear GPS errors while allowing all legitimate skiing/snowboarding speeds.

## Stage 2: Exponential Moving Average

After spike rejection, apply light smoothing using exponential moving average (EMA):

```
if firstReading:
    smoothed = velocity
else:
    smoothed = alpha × velocity + (1 - alpha) × previousSmoothed
```

### Configuration Parameters

- **`alpha`**: Weight given to new reading (default: 0.6)
  - Higher alpha (0.7-0.9) = more responsive, less smooth
  - Lower alpha (0.3-0.5) = smoother, more lag
  - Default 0.6 gives 60% weight to new value, 40% to history

### Why EMA Instead of Moving Average

**Advantages of EMA:**
- **No buffer needed**: Only tracks single previous value
- **Minimal lag**: Responds in 1-2 readings instead of 5-10
- **Continuous adaptation**: Naturally handles transitions between stops and movement
- **Simple**: Just one multiplication and addition per reading

**Disadvantages of Moving Average:**
- **High lag**: 5-point average = 5× the reading interval
- **Buffer overhead**: Must store N previous readings
- **Poor at transitions**: Takes full window size to adapt to changes

## Example Configuration for Skiing/Snowboarding

```
VelocitySmootherConfig:
  absoluteMaxValue: 30.0 mph (48.0 km/h)
  spikeMultiplier: 3.0
  minValueThreshold: 1.0 mph (1.6 km/h)
  alpha: 0.6
```

### Rationale

- **absoluteMaxValue = 30 mph**: Realistic maximum for skiing/snowboarding downhill
- **spikeMultiplier = 3.0**: Allows 3× speed increases (e.g., 10→30 mph) before rejection
- **minValueThreshold = 1.0 mph**: Below this is considered stopped
- **alpha = 0.6**: Responsive (60% new reading) while still smoothing GPS jitter

## Algorithm Behavior

### Scenario 1: GPS Spike (Rejected)

```
Raw:       [5, 5, 50, 6, 5]  (50 > absoluteMax AND > 3×5)
Accepted:  [5, 5, 5, 6, 5]   (spike rejected, previous value used)
Smoothed:  [5.0, 5.0, 5.0, 5.4, 5.2]  (EMA with alpha=0.6)
```

### Scenario 2: Rapid Acceleration (Accepted)

```
Raw:       [5, 5, 20, 25, 28]  (rapid but realistic acceleration)
Accepted:  [5, 5, 20, 25, 28]  (all accepted: < absoluteMax, realistic progression)
Smoothed:  [5.0, 5.0, 11.0, 19.4, 24.76]  (EMA responds quickly)
```

### Scenario 3: User Stops Moving

```
Raw:       [8, 6, 4, 0, 0, 0, 0]
Accepted:  [8, 6, 4, 0, 0, 0, 0]  (stops always preserved)
Smoothed:  [8.0, 6.8, 5.12, 2.05, 0.82, 0.33, 0.13]  (EMA decays to zero)
```

### Scenario 4: User Starts Moving

```
Raw:       [0, 0, 0, 3, 8, 15]
Accepted:  [0, 0, 0, 3, 8, 15]  (realistic acceleration accepted)
Smoothed:  [0, 0, 0, 1.8, 5.52, 11.21]  (EMA ramps up quickly)
```

## Implementation Notes

### Real-Time Application

For real-time velocity display, maintain only the previous smoothed value:

```
class VelocitySmoother {
    private var previousSmoothed: Double? = nil
    private let config: VelocitySmootherConfig

    func addReading(_ velocity: Double) -> Double {
        // Stage 1: Spike rejection
        var accepted = velocity

        if velocity >= config.minValueThreshold {
            // Not a stop - check for spikes
            if let prev = previousSmoothed {
                let isSpike = velocity > config.absoluteMaxValue &&
                             velocity > config.spikeMultiplier * prev
                if isSpike {
                    accepted = prev  // Reject spike, use previous
                }
            }
        }

        // Stage 2: EMA smoothing
        let smoothed: Double
        if let prev = previousSmoothed {
            smoothed = config.alpha * accepted + (1 - config.alpha) * prev
        } else {
            smoothed = accepted  // First reading
        }

        previousSmoothed = smoothed
        return smoothed
    }

    func reset() {
        previousSmoothed = nil
    }
}
```

### State Management

- **Single value storage**: Only `previousSmoothed` needs to be tracked
- **No buffer overhead**: O(1) memory per smoother instance
- **Fast response**: Output available immediately (no buffering delay)
- **Easy reset**: For new tracking sessions, just set `previousSmoothed = nil`

### Edge Cases

- **First reading**: No previous value, so skip spike check and EMA (just return raw value)
- **Stops**: Values < minValueThreshold are always accepted (preserves stop detection)
- **Missing readings**: Handled by caller (don't call addReading for missing data)
- **Long gaps**: previousSmoothed remains valid; EMA will adapt within 2-3 readings

## Data Model Integration

The smoothing algorithm operates on individual velocity readings:

```
Input:  Double      // Single velocity reading (in mph or km/h)
Output: Double      // Smoothed velocity
```

For batch processing of historical data:
```
func smoothVelocities(_ velocities: [Double?]) -> [Double?] {
    let smoother = VelocitySmoother(config: config)
    return velocities.map { velocity in
        guard let v = velocity else { return nil }
        return smoother.addReading(v)
    }
}
```

## Performance Considerations

- **Spike Rejection**: O(1) - simple comparison
- **EMA**: O(1) - single multiplication and addition
- **Memory**: O(1) - only previous value stored
- **Real-time latency**: Immediate (no buffering)

## Testing Recommendations

1. **GPS spikes**: Test with artificial spikes (> 30 mph) - should be rejected
2. **Rapid acceleration**: Test 0→20 mph in 2 readings - should be accepted
3. **Stop detection**: Verify values < 1 mph always preserved
4. **Responsiveness**: Test that smoothed output follows trends within 1-2 readings
5. **Real data**: Use school.gpx test data to validate against actual skiing patterns

## References

- Exponential Moving Average: https://en.wikipedia.org/wiki/Moving_average#Exponential_moving_average
- GPS Accuracy in Sports: Malone et al. (2017) "Unpacking the Black Box: Applications and Considerations for Using GPS Devices in Sport"
- Real-world skiing data analysis: shared/testing_data/gpx/school.gpx
- Time Series Smoothing: Cleveland (1979) "Robust Locally Weighted Regression and Smoothing Scatterplots"
