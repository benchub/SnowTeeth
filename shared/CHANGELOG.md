# Shared Logic Changelog

Track changes to shared algorithms, constants, and specifications.

## [0.4.0] - 2025-10-31

### Added
- `algorithms/gps_point_optimization.md` - GPS point deduplication algorithm
  - Removes redundant stationary points from GPX tracks
  - Reduces file size by ~50% for typical sessions with stops
  - Preserves timing information (when stopped and when resumed)
  - Compares exact lat/lon equality of three consecutive points
  - Removes middle point when all three are identical
  - Maintains first point (marks stop start) and current point (might move next)

### Changed
- **Average velocity calculation now excludes stationary points**
  - Added minimum speed threshold: 0.5 m/s (≈ 1.1 mph ≈ 1.8 km/h)
  - Average downhill/uphill pace only calculated from moving points
  - Stationary periods (stops, lift lines) no longer drag down averages
  - Result: Stats show speed **while actively moving**, not including stops
  - Updated `algorithms/stats_calculation.md` with new calculation method
- `iOS/SnowTeeth/Utilities/GpxWriter.swift` - Added `secondPreviousLocation` tracking and moving point counters
- `android/app/src/main/java/com/snowteeth/app/util/GpxWriter.kt` - Added `secondPreviousLocation` tracking and moving point counters

### GPS Point Optimization Algorithm
Recording at 1 Hz generates many redundant points during stationary periods (waiting at lifts, taking breaks). This algorithm:

- **Detection**: Checks if current point and two previous points have identical lat/lon
- **Action**: Removes the middle point before adding the current point
- **Result**: Stationary periods compressed to 2 points (start and end timestamps)
- **Impact**: ~50% file size reduction on typical ski sessions

Example:
```
Input:  10 minutes stationary (600 points at same location)
Output: 2 points (timestamp when stopped, timestamp at end of period)
```

---

## [0.3.2] - 2025-10-28

### Added
- `algorithms/velocity_smoothing.md` - Complete velocity smoothing specification
  - Two-stage algorithm: outlier detection + moving average
  - MAD (Median Absolute Deviation) based outlier detection
  - Preserves stops while removing GPS noise bursts
  - Configurable parameters for different use cases
  - Example configuration for skiing/snowboarding
  - Real-time implementation guidance with circular buffer

### Velocity Smoothing Algorithm
GPS velocity readings contain noise and occasional unrealistic spikes. This algorithm smooths the data while preserving legitimate stops:

- **Stage 1: Outlier Detection**
  - Uses Median Absolute Deviation (MAD) to identify statistical outliers
  - Calculates statistics from movement data only (excludes stops)
  - Replaces outliers with median of nearby valid values
  - Preserves values below minimum threshold (stops)

- **Stage 2: Moving Average**
  - Applies centered window averaging to reduce noise
  - Configurable window size (default: 5 readings)
  - Handles nil values gracefully

- **Key Features**
  - `minValueThreshold`: Values below this are always preserved (e.g., 1.0 mph for stops)
  - `absoluteMaxValue`: Hard ceiling for realistic velocities (e.g., 30 mph for skiing)
  - `madMultiplier`: Controls outlier sensitivity (default: 3.0)
  - Real-time application using circular buffer of recent readings

- **Example**: GPS burst of 25 mph among readings of 5-6 mph → replaced with nearby median (~5.5 mph)
- **Example**: User stops (0 mph) → zeros preserved, system detects stop immediately

---

## [0.3.1] - 2025-10-28

### Changed
- `algorithms/visualization_rendering.md` - Flame visualization specification
  - **CRITICAL ADDITION**: Documented parameter interpolation algorithm
  - All 10 flame parameters must smoothly interpolate between velocity buckets
  - Interpolation factor provided by velocity calculator (0.0 to 1.0)
  - Formula: `value = valueA + (valueB - valueA) * factor`
  - Prevents jarring transitions when crossing bucket boundaries
  - Added concrete examples with calculations
  - Specified edge cases (idle, exact threshold, above hard threshold)

### Flame Parameter Interpolation
Previously the specification was ambiguous about whether flame parameters should switch abruptly or interpolate smoothly. This update clarifies:
- **When in Easy bucket**: Interpolate between idle and easy presets
- **When in Medium bucket**: Interpolate between easy and medium presets
- **When in Hard bucket**: Interpolate between medium and hard presets
- **Example**: At 4 mph (halfway between easy and medium thresholds), height should be exactly halfway between easy height (0.93) and idle height (0.5) = 0.715

This ensures the flame grows and changes color smoothly as speed changes, not in discrete jumps.

---

## [0.3.0] - 2025-10-28

### Changed
- Replaced "Colors" visualization with "Data" visualization
- Updated visualization style enum: COLORS → DATA

### Data Visualization
- Real-time GPS data display with character morphing animations
- Top half: Large velocity display with unit label
- Bottom half: Latitude, longitude, and altitude information
- Character morphing: Direct old→new transition with horizontal compression (no intermediate "|")
- Monospaced digits with proportional punctuation for clean decimal alignment
- Fixed-width formatting: velocity (%5.1f), altitude (%4.0f)
- Updates every 2 seconds for smooth animations

### iOS Implementation (v0.3.0)
- Added `Views/DataVisualizationView.swift` - SwiftUI-based data display
- MorphingText component with character-by-character animation
- Uses `.monospacedDigit()` for aligned numbers with narrow periods
- Separate morphing state for velocity, latitude, longitude, altitude
- 2-second update timer for GPS data
- 60fps animation timer for smooth morphing

### Android Implementation (v0.3.0)
- Added `view/DataVisualizationView.kt` - Custom view with Canvas rendering
- Character morphing with ValueAnimator (1 second duration)
- Uses `fontFeatureSettings = "tnum"` for tabular numbers with proportional punctuation
- Separate morphing state maps for each field
- Paint objects with monospace velocity (bold) and proportional GPS data
- GPS data displayed via broadcast receiver from LocationTrackingService

### Typography
- Velocity: Bold with tabular numbers (iOS: .monospacedDigit(), Android: "tnum")
- Unit label: Regular, smaller size below velocity
- GPS data: Regular with proportional spacing for better fit
- Period/decimal: Narrow proportional width (matches iOS behavior)

### Configuration Screen Updates
- Replaced "Use Metric" toggle with "Empire!" / "Science!" segmented control
- Automatic threshold conversion when switching units (1.60934 factor)
- Automatic max value adjustment for threshold bars
- Updated headers to show current unit (mph / km/h)

---

## [0.2.0] - 2025-10-27

### Added
- `algorithms/yeti_visualization.md` - Complete Yeti state machine specification
- `constants/yeti_state_mapping.json` - Bucket-to-state mappings for Yeti
- `constants/yeti_video_weights.json` - Weighted video variant selection
- `copy_videos.sh` - Script to symlink videos to iOS and Android bundles

### Yeti Visualization
- State machine-based video player with gradual transitions
- 4 intensity states: idle (0), easy (1), medium (2), hard (3)
- Videos for all one-step transitions (up, down, same-state)
- Weighted random selection for same-state loop variants
- 30 video files covering all transitions with multiple variants

### Yeti Algorithm Features
- Gradual one-step transitions (prevents jarring jumps)
- Velocity sampling at video end for dynamic state determination
- Multiple variants for same-state loops with configurable weights
- Example weights: "0 to 0 b" (3.0) is 3x more likely than "0 to 0 a" (1.0)

### iOS Implementation (v0.2.0)
- Added `Views/YetiVisualizationView.swift` - AVPlayer-based video playback
- YetiStateMachine class with bucket-to-state logic
- Weighted random selection algorithm
- Updated `VisualizationStyle` enum to include `.yeti`
- Updated `VisualizationView.swift` to support Yeti style
- Videos symlinked to `Resources/Videos/` (30 files)

### Android Implementation (v0.2.0)
- Added `view/YetiVisualizationView.kt` - MediaPlayer-based video playback
- Weighted random selection algorithm matching iOS
- Updated `VisualizationStyle` enum to include `YETI`
- Updated `VisualizationActivity.kt` to support Yeti style
- Videos symlinked to `assets/videos/` (30 files)

### Development Workflow
- Videos stored in `/video/` directory
- Symlinked to app bundles (not copied) for efficient development
- Build process copies symlinked files into app packages
- Run `./copy_videos.sh` to set up symlinks

---

## [0.1.0] - 2025-10-27

### Added
- `constants/flame_presets.json` - Flame visualization parameter presets
- Complete 3D volumetric flame shader specification
- Four preset configurations: idle, easy, medium, hard
- Shader parameter descriptions and valid ranges

### Changed
- `algorithms/visualization_rendering.md` - Updated with actual flame algorithm
  - Replaced placeholder flame specification with complete raymarching algorithm
  - Added technical details for iOS (Metal) and Android (OpenGL ES) implementations
  - Documented temperature-to-color mapping
  - Specified preset-to-bucket mapping
  - Included animation continuity requirements

### Flame Algorithm Specified
- Volumetric raymarching with 35-50 iterations
- Multi-octave turbulence (6-8 octaves)
- Hollow cone signed distance field
- Temperature-based color gradient (red → white)
- Tanh tone mapping for HDR-like appearance
- 10 tunable parameters per preset

### Preset Parameters
- Idle: Gentle, small, reddish flame
- Easy: Moderate orange flame
- Medium: Large yellow flame with twist
- Hard: Intense red/white flame, very fast

### iOS Implementation (v0.1.0)
- Added `Views/FireShader.metal` - Metal compute shader
- Added `Views/FireShaderView.swift` - MTKView wrapper
- Updated `Views/VisualizationView.swift` - Integrated flame shader with preset switching
- Flame visualization now fully functional in Flame mode

### Android Implementation (v0.1.0)
- Added `view/FireShaderView.kt` - OpenGL ES implementation with embedded shaders
- Updated `VisualizationActivity.kt` - Dynamic view switching between Flame and Colors
- Flame visualization now fully functional in Flame mode

---

## [0.0.1] - 2025-10-27

### Added
- Initial shared directory structure
- `constants/thresholds.json` - Default thresholds and conversion factors
- `algorithms/velocity_calculation.md` - Velocity bucket determination
- `algorithms/stats_calculation.md` - Statistics calculations
- `algorithms/visualization_rendering.md` - Rendering specifications
- `models/data_models.md` - Data structure definitions
- `README.md` - Usage guide

### Constants Established
- Downhill thresholds: Easy 2.0, Medium 6.0, Hard 10.0 mph
- Uphill thresholds: Easy 1.0, Medium 3.0, Hard 5.0 mph
- Minimum threshold gap: 0.5
- Slider ranges: Downhill 1.0-30.0, Uphill 0.5-15.0

### Algorithms Documented
- Velocity bucket calculation based on speed and elevation
- Color interpolation for smooth transitions
- Haversine distance calculation
- Vertical gain/loss accumulation
- Ascent/descent counting with tolerance for small interruptions

### Rendering Specified
- Flame mode: Shapes and exact dimensions (placeholder)
- Colors mode: Color interpolation algorithm
- Exact hex color values for all buckets
- Performance targets (60 fps)

---

## Template for Future Changes

When making changes, document them here:

```
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features or algorithms

### Changed
- Modifications to existing logic
- Updated constants

### Deprecated
- Features being phased out

### Removed
- Deleted functionality

### Fixed
- Bug fixes in algorithm descriptions

### iOS Implementation
- Version where iOS was updated

### Android Implementation
- Version where Android was updated
```
