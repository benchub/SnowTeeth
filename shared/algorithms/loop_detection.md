# Loop Detection Algorithm

## Overview

This algorithm detects when a user completes laps/loops on a track or similar repeated path. It efficiently identifies the first loop completion and subsequent laps while determining if they follow roughly the same path.

## Problem Statement

- **Goal**: Detect when GPS track forms loops (like running laps on a track)
- **Challenges**:
  - GPS noise/error (typically 5-10m accuracy)
  - Need real-time processing on mobile devices
  - Must distinguish similar loops from different paths
- **Constraints**: Must be computationally efficient for battery-constrained devices

---

## Algorithm Design

### Phase 1: First Loop Detection

**Objective**: Detect when the path first intersects itself, forming a closed loop.

**Method**:
1. Store all GPS points in a list as they arrive
2. For each new GPS point:
   - Check if it's within **LOOP_START_THRESHOLD** (20m) of any previous point
   - Ignore points from the last 30 seconds to avoid premature detection
3. When intersection detected:
   - The segment from the intersection point to current point forms the first loop
   - Store this as the **reference loop**
   - Mark the intersection point as the **lap point**
   - Switch to Phase 2

**Optimization**: Use spatial indexing (grid or k-d tree) to avoid checking every previous point.

### Phase 2: Subsequent Loop Detection

**Objective**: Detect when user completes additional loops and verify they follow the same path.

**Method**:
1. Track distance from lap point continuously
2. When user comes within **LAP_THRESHOLD** (25m) of lap point:
   - Consider this a potential lap completion
   - Extract path since last lap point as **candidate loop**
3. Compare candidate loop to reference loop using similarity check (below)
4. If similar enough:
   - Increment lap counter
   - Update statistics (lap time, distance, etc.)
5. If not similar:
   - Log as "deviation" but continue tracking
   - May indicate user took a different route

---

## Path Similarity Algorithm

To efficiently compare two GPS paths:

### Step 1: Simplify Paths

Use **Douglas-Peucker algorithm** with epsilon=10m to reduce point count while preserving shape:
- Recursively removes points that deviate less than epsilon from the line between endpoints
- Typically reduces 1000+ points to 20-50 points
- Preserves the essential shape of the path

### Step 2: Length Check

Quick rejection test:
- If loop lengths differ by more than **LENGTH_TOLERANCE** (20%), reject as different loop
- Prevents expensive comparison for obviously different paths

### Step 3: Hausdorff-Style Distance

Compute bidirectional similarity:

**Forward distance** (candidate → reference):
```
for each point P in simplified candidate loop:
    find closest point in reference loop
    record distance D
average all distances → forward_distance
```

**Backward distance** (reference → candidate):
```
for each point P in simplified reference loop:
    find closest point in candidate loop
    record distance D
average all distances → backward_distance
```

**Similarity score**:
```
max_deviation = max(forward_distance, backward_distance)
```

If `max_deviation < SIMILARITY_THRESHOLD` (30m), loops are considered matching.

### Step 4: Directional Check

Verify loops traverse in same direction:
- Sample 3-5 evenly spaced points from reference loop
- For each, find closest point in candidate loop and check if index increases
- If indices decrease (reverse direction), mark as reverse lap
- If indices jump around randomly, likely different path

---

## Constants

```
LOOP_START_THRESHOLD = 20m    // Distance to detect first loop closure
LAP_THRESHOLD = 25m           // Distance to lap point to trigger lap detection
MIN_LOOP_TIME = 30s           // Minimum time for a valid loop (prevents false positives)
MIN_LOOP_DISTANCE = 100m      // Minimum loop length to be considered valid

SIMPLIFICATION_EPSILON = 10m  // Douglas-Peucker tolerance
LENGTH_TOLERANCE = 0.20       // 20% difference in length allowed
SIMILARITY_THRESHOLD = 30m    // Max average deviation for matching loops
```

---

## Data Structures

### GPSPoint
```
{
    latitude: Double
    longitude: Double
    altitude: Double
    timestamp: Timestamp
    distanceFromLapPoint: Double  // Cached for efficiency
}
```

### Loop
```
{
    id: Int                        // Loop number (1, 2, 3...)
    points: List<GPSPoint>         // Full resolution points
    simplifiedPoints: List<GPSPoint>  // Douglas-Peucker simplified
    distance: Double               // Total loop distance
    duration: TimeInterval         // Time to complete
    averageSpeed: Double
    elevationGain: Double
    startTime: Timestamp
    endTime: Timestamp
}
```

### LoopTracker State
```
{
    phase: Enum(DETECTING_FIRST, TRACKING_LAPS)
    allPoints: List<GPSPoint>
    referenceLoop: Loop?
    lapPoint: GPSPoint?
    currentLoopStartIndex: Int
    completedLoops: List<Loop>
    spatialIndex: GridIndex or KDTree  // For efficient proximity queries
}
```

---

## Spatial Indexing

To avoid O(n²) comparisons when checking if new point intersects previous path:

### Grid-Based Index

**Structure**:
- Divide space into 50m × 50m grid cells
- Each cell contains list of point indices that fall within it
- New point only checks against points in same cell and 8 neighbors (3×3 grid)

**Operations**:
```
insert(point, index):
    cell = getCell(point.lat, point.lon)
    cell.points.append(index)

findNearbyPoints(point, radius):
    cells = get3x3NeighborCells(point)
    candidates = []
    for cell in cells:
        candidates += cell.points
    return candidates.filter(distance < radius)
```

**Efficiency**: Reduces search from O(n) to O(k) where k ≈ 10-50 points per cell

---

## Algorithm Complexity

### Time Complexity
- **First loop detection**: O(k) per point where k = points per grid cell (~10-50)
  - With 1 point per second, 10 minutes = 600 points → ~30,000 comparisons total
- **Subsequent lap detection**: O(n × m) where n, m = simplified point counts (~20-50 each)
  - Per lap: ~500-2,500 distance calculations
- **Douglas-Peucker simplification**: O(n log n) where n = points in loop

### Space Complexity
- **GPS points**: 40 bytes per point × 3600 points/hour = ~140 KB/hour
- **Grid index**: ~200 cells × 8 bytes = 1.6 KB
- **Reference loop**: ~2 KB (simplified)
- **Total**: Under 1 MB even for multi-hour sessions

### Battery Impact
- Minimal: Uses existing GPS data stream
- No continuous distance calculations between all points
- Spatial indexing reduces CPU load by ~100x vs naive approach
- Lap detection only runs when near lap point

---

## Edge Cases

1. **Figure-8 loops**: Will detect two separate loops at intersection point
   - Solution: Store multiple reference loops, match to closest

2. **Varying lap length**: User takes shortcut or wider turn
   - Solution: LENGTH_TOLERANCE of 20% allows minor variations

3. **GPS drift**: Stationary user appears to move in small circle
   - Solution: MIN_LOOP_DISTANCE prevents <100m loops from counting

4. **Multi-lap track**: Track with inner and outer loops
   - Solution: When deviation exceeds threshold, start tracking new reference loop

5. **Reverse direction**: User runs loop backwards
   - Solution: Directional check detects and logs as reverse lap

---

## Implementation Notes

### iOS
- Use CoreLocation for GPS data
- Implement spatial index using `Dictionary<GridCell, [Int]>`
- Store loops in memory, persist to CoreData on app backgrounding
- Run loop detection on background thread to avoid UI lag

### Android
- Use Google Location Services for GPS data
- Implement spatial index using `HashMap<GridCell, List<Int>>`
- Store loops in Room database
- Run loop detection in coroutine on IO dispatcher

### Performance Monitoring
- Track time spent in loop detection per GPS update
- Target: <10ms per point on mid-range hardware
- Alert if exceeding 50ms (indicates optimization needed)

---

## Future Enhancements

1. **Machine learning**: Train model to identify track shapes
2. **Multi-reference loops**: Support tracks with multiple valid paths
3. **Adaptive thresholds**: Adjust tolerances based on GPS accuracy
4. **Loop prediction**: Estimate lap time based on current pace
5. **Track database**: Share and match against known track geometries

---

## References

- **Douglas-Peucker Algorithm**: Ramer (1972), Douglas & Peucker (1973)
- **Hausdorff Distance**: For comparing shapes/curves
- **Fréchet Distance**: Alternative metric for curve similarity
- **GPS Accuracy**: Typical smartphone GPS: 5-10m CEP (Circular Error Probable)
