# SnowTeeth Shared Logic

This directory contains the **single source of truth** for business logic, algorithms, constants, and data models shared between the iOS and Android implementations of SnowTeeth.

## Purpose

When making changes to the app's core functionality, this directory serves as:
1. **Reference implementation** - Defines how algorithms should work
2. **Constants library** - Central place for all magic numbers and default values
3. **Documentation** - Explains the "why" and "what" of the business logic
4. **Synchronization point** - Ensures iOS and Android stay consistent

## Directory Structure

```
shared/
├── README.md                      # This file
├── CHANGELOG.md                   # Version history of shared logic changes
├── constants/                     # Configuration values
│   ├── thresholds.json           # Velocity thresholds and conversion factors
│   ├── flame_presets.json        # Flame visualization parameter presets
│   ├── yeti_state_mapping.json   # Yeti state machine mappings
│   └── yeti_video_weights.json   # Video variant selection weights
├── algorithms/                    # Business logic documentation
│   ├── velocity_calculation.md   # How to determine velocity buckets
│   ├── velocity_smoothing.md     # GPS noise filtering and smoothing
│   ├── gps_point_optimization.md # Redundant GPS point removal
│   ├── stats_calculation.md      # How to calculate statistics
│   ├── visualization_rendering.md # Flame/Yeti/Data visualization specs
│   └── yeti_visualization.md     # Yeti state machine details
├── models/                        # Data structure definitions
│   └── data_models.md            # All data types and their relationships
├── reference_implementations/     # Code examples for complex algorithms
│   └── TimeSeriesSmoothing.swift # Swift reference for velocity smoothing
└── media/                         # Shared assets (future)
    └── (icons, images, etc.)
```

## How to Use This Directory

### For Developers

When implementing a feature:
1. Check `shared/` first to see if the logic is already defined
2. Follow the documented algorithms exactly
3. Use constants from JSON files in `constants/`
4. Ensure your implementation matches the data models
5. For complex algorithms, refer to `reference_implementations/` for working code examples

### For AI Assistant (Claude)

When making changes to the app:
1. **Before changing logic**: Update the shared documentation first
2. **When updating constants**: Modify `thresholds.json`, then sync both apps
3. **When adding features**: Document the algorithm in `shared/algorithms/`
4. **After changes**: Verify both iOS and Android match the shared spec

## Workflow for Changes

### Example: Changing Default Thresholds

1. Update `shared/constants/thresholds.json`:
   ```json
   "downhill": {
     "easy": 3.0,  // Changed from 2.0
     ...
   }
   ```

2. Update iOS: `iOS/SnowTeeth/Utilities/AppPreferences.swift`
   ```swift
   static let defaultDownhillEasy: Float = 3.0
   ```

3. Update Android: `android/app/src/main/java/com/snowteeth/app/util/AppPreferences.kt`
   ```kotlin
   const val DEFAULT_DOWNHILL_EASY = 3.0f
   ```

### Example: Modifying Velocity Calculation Algorithm

1. Update `shared/algorithms/velocity_calculation.md` with the new algorithm
2. Implement in iOS: `iOS/SnowTeeth/Utilities/VelocityCalculator.swift`
3. Implement in Android: `android/app/src/main/java/com/snowteeth/app/util/VelocityCalculator.kt`
4. Update tests in both platforms to match new behavior

### Example: Adding a New Visualization Style

1. Document in `shared/models/data_models.md`:
   ```
   enum VisualizationStyle {
       FLAME,
       COLORS,
       GRADIENT  // NEW
   }
   ```

2. Update iOS enum and implementation
3. Update Android enum and implementation
4. Update configuration UI in both apps

## Consistency Guarantees

The following must be **identical** across platforms:

### Calculations
- Velocity bucket determination
- Color interpolation factors
- Statistics calculations (distance, elevation, counts)
- GPS data validation thresholds

### Constants
- Default threshold values
- Conversion factors (mph↔kph, meters↔feet)
- Minimum gaps between thresholds
- Slider min/max ranges

### Data Models
- Enum values (VelocityBucket, VisualizationStyle)
- Struct fields (LocationData, StatsData)
- Validation rules

### File Formats
- GPX structure and naming
- Timestamp formats
- Coordinate precision

## Platform-Specific Differences

These are **allowed** to differ:

### UI/UX
- Native UI components and styling
- Navigation patterns (NavigationView vs Activities)
- Platform-specific animations

### Technical Implementation
- Swift vs Kotlin syntax
- State management (ObservableObject vs LiveData)
- Threading models (async/await vs coroutines)

### Platform Features
- iOS: Keep screen awake with `UIApplication.shared.isIdleTimerDisabled`
- Android: Keep screen awake with `Window.addFlags(FLAG_KEEP_SCREEN_ON)`

## Testing

When changes are made:

1. **Unit Tests**: Both platforms should have tests covering the same scenarios
   - Test velocity calculation with same inputs → same outputs
   - Test stats calculation with same GPX data → same results
   - Test threshold validation with same edge cases

2. **Integration Tests**: Verify GPX files are compatible
   - Export GPX from iOS, verify it can be read by Android (and vice versa)
   - Same track should produce same statistics

3. **Manual Testing**: Use same test scenario on both platforms
   - Configure with same thresholds
   - Use location simulation with same GPS data
   - Verify visualizations show same colors/shapes

## Version History

### v1.4.0 (2025-10-31)
- Added GPS point optimization algorithm
- Removes redundant stationary points from GPX tracks
- ~50% file size reduction for typical sessions

### v1.0.0 (2025-10-27)
- Initial shared directory structure
- Documented velocity calculation algorithm
- Documented stats calculation algorithm
- Defined data models
- Established constants

## Contributing

When adding to this directory:

1. **Be explicit**: Don't assume implementation details
2. **Include examples**: Show concrete calculations with real numbers
3. **Explain edge cases**: What happens when GPS is bad, thresholds are equal, etc.
4. **Keep it simple**: Prefer clarity over cleverness
5. **Update both**: If you change shared docs, update both implementations

## Future Enhancements

Potential additions to this directory:

- [ ] Visualization rendering specifications (exact colors, shapes, sizes)
- [ ] Animation timing curves and durations
- [ ] Audio feedback specifications (if added)
- [ ] Network protocol (if cloud sync is added)
- [ ] Shared test data (sample GPX files for testing)
- [ ] Performance benchmarks and targets

## Questions?

If something is unclear or missing from this shared directory, it should be added. The goal is to make it impossible to implement the apps inconsistently.
