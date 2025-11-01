# Visualization Rendering Specifications

## Overview

All visualization styles (Flame, Data, and Yeti) must render identically across iOS and Android platforms. This document specifies exact colors, shapes, sizes, and behaviors.

---

## Visualization Style: FLAME

### Overview
The Flame visualization uses an optimized **2D fire shader** to render an animated fire effect suitable for low-end hardware. The flame's appearance (size, intensity, color, movement) changes based on the current velocity bucket. This implementation is based on "One-Pass Fire" by @XorDev and prioritizes performance while maintaining visual quality.

### Technical Approach

#### iOS Implementation
- **Framework**: Metal
- **Shader Language**: Metal Shading Language (MSL)
- **View**: MTKView with compute shader
- **File**: FireShader.metal
- **Additional Resources**: Noise texture for fire detail

#### Android Implementation
- **Framework**: OpenGL ES 3.0
- **Shader Language**: GLSL ES 3.00
- **View**: GLSurfaceView with fragment shader
- **Files**: fire_shader.frag, fire_shader.vert
- **Additional Resources**: Noise texture for fire detail

### Algorithm Overview

The flame is rendered using a **2D distance-based approach with turbulence**:
1. Transform screen coordinates to flame space (centered, aspect-corrected)
2. Apply vertical and horizontal stretching for flame shape
3. Apply multi-octave turbulence (8 iterations) for organic motion
4. Calculate distance to fireball center
5. Compute lighting based on distance with cubic falloff
6. Sample noise texture for additional fire detail
7. Apply temperature-based color mapping
8. Tone map result using exponential curve

### Shader Parameters

Each velocity bucket maps to a specific preset configuration:

| Parameter | Type | Range | Description |
|-----------|------|-------|-------------|
| speed | float | 0.2-1.4 | Animation speed multiplier (controls time offset) |
| intensity | float | 0.5-2.1 | Brightness/visibility |
| height | float | 0.3-0.8 | Vertical extent (flame size) |
| colorShift | float | 0.5-1.8 | Temperature mapping (cooler→hotter colors) |
| baseWidth | float | 0.3-0.9 | Horizontal width at base |
| colorBlend | float | 0.7-1.8 | Core-to-edge color blending factor |
| noisePattern | float | 15.0 | Noise texture frequency (typically constant) |

### Preset Configurations

See `shared/constants/flame_presets.json` for exact values.

**Idle Preset** (VelocityBucket.IDLE):
```
speed: 0.2, intensity: 0.5, height: 0.33
colorShift: 0.5, baseWidth: 0.3
colorBlend: 1.77, noisePattern: 15.0
```
*Appearance*: Small, dim, reddish flame with subtle movement

**Easy Preset** (DOWNHILL_EASY, UPHILL_EASY):
```
speed: 0.47, intensity: 1.98, height: 0.44
colorShift: 0.72, baseWidth: 0.3
colorBlend: 0.67, noisePattern: 15.0
```
*Appearance*: Moderate orange flame with increased brightness

**Medium Preset** (DOWNHILL_MEDIUM, UPHILL_MEDIUM):
```
speed: 0.81, intensity: 0.67, height: 0.74
colorShift: 1.13, baseWidth: 0.51
colorBlend: 1.42, noisePattern: 15.0
```
*Appearance*: Taller yellow-orange flame, wider base

**Hard Preset** (DOWNHILL_HARD, UPHILL_HARD):
```
speed: 1.36, intensity: 2.02, height: 0.58
colorShift: 1.73, baseWidth: 0.82
colorBlend: 1.13, noisePattern: 15.0
```
*Appearance*: Very bright flame with hot colors, fast animation, wide base

**Alternate Ascent Preset** (UPHILL_ALTERNATE - Optional Mode):
```
speed: 0.88, intensity: 0.5, height: 0.1
colorShift: 1.36, baseWidth: 0.3
colorBlend: 1.62, noisePattern: 15.0
```
*Appearance*: Small, low flame with moderate temperature, subtle width
*Usage*: When alternate ascent visualization mode is enabled, this preset replaces ALL uphill buckets (UPHILL_EASY, UPHILL_MEDIUM, UPHILL_HARD) with a single consistent visualization

### Alternate Ascent Mode

**Purpose**: Some users may prefer a different visual representation when going uphill. Instead of scaling the flame intensity based on uphill speed (easy/medium/hard), the alternate ascent mode uses a single, consistent flame appearance for all uphill conditions.

**Behavior**:
- **Default Mode**: Downhill uses 3 buckets (easy/medium/hard), Uphill uses 3 buckets (easy/medium/hard)
- **Alternate Ascent Mode**: Downhill uses 3 buckets (easy/medium/hard), Uphill uses 1 preset (alternate ascent) regardless of speed

**Implementation**:
1. Add a user-configurable toggle in app settings: "Use Alternate Ascent Visualization"
2. When enabled, detect if current velocity bucket is uphill (UPHILL_EASY, UPHILL_MEDIUM, or UPHILL_HARD)
3. If uphill, bypass normal velocity bucket preset and use the Alternate Ascent Preset
4. No interpolation between uphill buckets - use constant values
5. Transition smoothly when switching between downhill (normal) and uphill (alternate)

**Interpolation Notes**:
- When transitioning from downhill to uphill: Interpolate from current downhill preset to alternate ascent preset
- When in alternate ascent mode: No interpolation - use fixed alternate ascent values
- When transitioning from uphill to downhill: Interpolate from alternate ascent preset to current downhill preset
- When alternate mode is disabled: Resume normal interpolation between all buckets

### Core Algorithm Steps

#### 1. Coordinate Setup
```glsl
// Screen coordinates, centered and aspect-corrected
vec2 p = (fragCoord * 2.0 - iResolution) / iResolution.y;

// Flip Y so flame burns upward
p.y = -p.y;

// Apply width control
p.x /= baseWidth;
```

#### 2. Coordinate Stretching
```glsl
// Expand vertically (flame shape)
float xstretch = 2.0 - 1.5 * smoothstep(-2.0, 2.0, p.y);

// Decelerate horizontally
float ystretch = 1.0 - 0.5 / (1.0 + p.x * p.x);

// Apply combined stretch
vec2 stretch = vec2(xstretch, ystretch);
p *= stretch;
```

#### 3. Scrolling and Turbulence
```glsl
float scrollTime = 1.6 * iTime;

// Scroll upward
p.y -= scrollTime;

// Apply multi-octave turbulence (8 iterations)
float freq = 7.0;
mat2 rot = mat2(0.6, -0.8, 0.8, 0.6);
for(float i = 0.0; i < 8.0; i += 1.0) {
    vec2 rotP = p * rot;
    float phase = freq * rotP.y + 6.0 * iTime + i;
    p += 0.4 * rot[0] * sin(phase) / freq;
    rot = rot * mat2(0.6, -0.8, 0.8, 0.6);  // Rotate for next octave
    freq *= 1.3;  // Increase frequency
}

// Reverse scrolling offset
p.y += scrollTime;
```

#### 4. Distance Field and Lighting
```glsl
// Distance to fireball center
float RADIUS = 0.4 * height;
float dist = length(min(p, p / vec2(1, stretch.y))) - RADIUS;

// Cubic falloff for lighting
float distSq = dist * dist + 0.3 * max(p.y + 0.5, 0.0);
float light = 1.0 / (distSq * distSq * distSq);
```

#### 5. Color Mapping
```glsl
// Temperature-based core color
vec3 coreColor = temperatureToColor(colorShift);

// Red-orange edge color
vec3 edgeColor = vec3(1.0, 0.2, 0.0);

// Blend from core to edge based on distance
vec2 source = p + 2.0 * vec2(0, RADIUS) * stretch;
float centerDist = length(source);
float colorMix = smoothstep(0.0, colorBlend, centerDist);
vec3 flameColor = mix(coreColor, edgeColor, colorMix);
```

#### 6. Texture Sampling and Final Composition
```glsl
// Gradient with uniform falloff
float falloff = 0.1 / (1.0 + centerDist * 2.0);
vec3 grad = flameColor * falloff;

// Ambient lighting
vec3 amb = 16.0 / (1.0 + dot(p, p)) * grad;

// Sample noise texture
vec2 uv = (p - vec2(0, scrollTime)) / 100.0 * 7.0;
vec3 tex = texture(noiseTexture, uv).rgb;

// Combine components
vec3 col = amb + light * grad * tex * intensity;
```

#### 7. Tone Mapping
```glsl
// Exponential tonemap (compresses HDR to LDR)
col = 1.0 - exp(-col);
```

### Temperature-to-Color Mapping

The `temperatureToColor` function maps the colorShift parameter to realistic fire colors:

```
colorShift: 0.5 → Orange (cooler fire)
colorShift: 1.0 → Yellow (moderate heat)
colorShift: 1.5 → Cyan/Green (very hot)
colorShift: 2.0 → Blue/White (extreme heat)
```

Color gradient progression:
```
Orange → Yellow → Green → Cyan → Blue → White
```

The function uses smoothstep blending for GPU-efficient, branchless interpolation.

### Animation Continuity

To ensure smooth animation:
1. Track cumulative time offset: `timeOffset += speed * deltaTime`
2. Smooth speed changes: `smoothedSpeed += (targetSpeed - smoothedSpeed) * 0.3`
3. Pass timeOffset to shader (not system time directly)

### Parameter Interpolation

**CRITICAL**: The flame parameters must **smoothly interpolate** between velocity buckets based on the current speed, NOT switch abruptly when crossing bucket boundaries.

#### Interpolation Algorithm

The velocity calculator provides an interpolation factor (0.0 to 1.0) indicating progress from one bucket threshold to the next. This factor is used to blend ALL flame parameters.

**Formula**:
```
interpolatedValue = valueA + (valueB - valueA) * interpolationFactor
```

Where:
- `valueA` = parameter value for current bucket
- `valueB` = parameter value for next bucket
- `interpolationFactor` = 0.0 at lower threshold, 1.0 at upper threshold

#### Example: Height Parameter

Given:
- Idle height: 0.5
- Easy height: 0.93
- Current speed: 1.5 mph (exactly halfway between idle→easy threshold range)

Calculation:
```
interpolationFactor = 0.5  // Halfway between thresholds
height = 0.5 + (0.93 - 0.5) * 0.5
height = 0.5 + 0.43 * 0.5
height = 0.5 + 0.215
height = 0.715
```

Result: The flame's height is 0.715, smoothly between idle and easy.

#### All Parameters Must Interpolate

**Every** flame parameter must interpolate simultaneously:
- speed
- intensity
- height
- colorShift
- baseWidth
- colorBlend

#### Velocity Bucket Boundaries

**Idle Bucket** (speed < easyThreshold):
- Use idle preset values
- No interpolation (already at minimum)

**Easy Bucket** (easyThreshold ≤ speed < mediumThreshold):
- Interpolate between idle and easy presets
- Factor = progress from easyThreshold to mediumThreshold

**Medium Bucket** (mediumThreshold ≤ speed < hardThreshold):
- Interpolate between easy and medium presets
- Factor = progress from mediumThreshold to hardThreshold

**Hard Bucket** (speed ≥ hardThreshold):
- Interpolate between medium and hard presets
- Factor = progress beyond hardThreshold (capped at 1.0)

#### Concrete Example: Full Parameter Set

Assume speed is 4.0 mph with thresholds:
- Easy: 2.0 mph
- Medium: 6.0 mph
- Hard: 10.0 mph

Current bucket: **Easy** (between 2.0 and 6.0)

Interpolation factor:
```
factor = (4.0 - 2.0) / (6.0 - 2.0)
factor = 2.0 / 4.0
factor = 0.5
```

Interpolated parameters:
```
speed     = 0.2  + (0.47 - 0.2 ) * 0.5 = 0.335
intensity = 0.5  + (1.98 - 0.5 ) * 0.5 = 1.24
height    = 0.33 + (0.44 - 0.33) * 0.5 = 0.385
colorShift= 0.5  + (0.72 - 0.5 ) * 0.5 = 0.61
baseWidth = 0.3  + (0.3  - 0.3 ) * 0.5 = 0.3
colorBlend= 1.77 + (0.67 - 1.77) * 0.5 = 1.22
```

Result: The flame appearance is exactly halfway between idle and easy presets.

#### Edge Cases

**Below Easy Threshold (Idle)**:
- Use pure idle preset values
- No interpolation needed

**At Exact Threshold**:
- interpolationFactor = 0.0
- Use lower bucket's preset exactly

**Above Hard Threshold**:
- Continue interpolating between medium and hard
- Cap interpolationFactor at 1.0 when speed >> hardThreshold
- This prevents parameter values from going out of range

**Uphill vs Downhill**:
- Apply same interpolation logic to uphill buckets
- Uphill has separate thresholds and presets but same algorithm

#### Visual Result

This interpolation ensures:
1. **No jarring transitions**: Flame grows/shrinks smoothly as speed changes
2. **Continuous appearance**: Color shifts gradually (red → orange → yellow)
3. **Natural feel**: Flame behavior matches velocity in real-time
4. **Predictable**: Users can intuitively understand flame intensity = speed

### Background
- Color: #000000 (Black)
- Fills entire screen

### Platform-Specific Notes

**iOS (Metal)**:
- Use MTKView with compute shader
- Thread group size: 16x16
- Target: 60 FPS at native resolution
- Optimization: 8 turbulence iterations, no raymarching
- Noise texture: Generated or loaded as Metal texture

**Android (OpenGL ES)**:
- Use GLSurfaceView with fragment shader
- Full-screen quad rendering with vertex shader
- Target: 60 FPS at native resolution
- Optimization: 8 turbulence iterations, no raymarching
- Noise texture: Generated or loaded as OpenGL texture

### Performance Characteristics

The new 2D fire shader is significantly more efficient than the previous 3D volumetric raymarching approach:

**Computational Complexity**:
- **No nested loops**: Single turbulence loop with 8 iterations per pixel
- **No raymarching**: Direct distance calculation instead of 35-50 raymarch steps
- **Single texture sample**: One noise texture lookup per pixel
- **Branchless execution**: All conditionals use smoothstep/mix for GPU efficiency

**Expected Performance**:
- Low-end mobile (iPhone SE, budget Android): 60 FPS at native resolution
- Mid-range mobile (iPhone 12, mid-range Android): 60 FPS at native resolution
- High-end mobile: 60 FPS at higher resolutions with headroom

**Memory Usage**:
- Minimal shader uniform data: ~32 bytes
- Noise texture: Typically 256x256 RGBA (256 KB)
- Total GPU memory: < 1 MB

---

## Visualization Style: DATA

### Overview

The Data visualization displays real-time GPS information with animated character transitions. This style emphasizes information over aesthetics, showing velocity and location data with smooth morphing animations.

### Layout

#### Screen Division
```
┌─────────────────────────────┐
│                             │
│         12.3                │  ← Top Half (50%)
│    miles per hour           │     Velocity + unit label
│                             │
├─────────────────────────────┤
│ Latitude:  37.7749          │  ← Bottom Half (50%)
│ Longitude: -122.4194        │     GPS information
│ Altitude:  142 m            │
└─────────────────────────────┘
```

### Display Elements

#### 1. Velocity Display (Top Half)
- **Position**: Centered in top 50% of screen
- **Font Size**: 15% of screen height
- **Font Weight**: Bold
- **Font Style**: Tabular numbers (monospaced digits, proportional punctuation)
  - iOS: `.monospacedDigit()`
  - Android: `fontFeatureSettings = "tnum"`
- **Color**: White (#FFFFFF)
- **Background**: Black (#000000)
- **Format**:
  - Fixed-width: `%5.1f` (always shows as "XXX.X" or " XX.X" or "  X.X")
  - Examples: " 12.3", "  9.5", "100.7"
  - Leading spaces ensure decimal point stays in fixed position
- **Alignment**: Center (horizontal and vertical within top half)

#### 2. Unit Label (Below Velocity)
- **Position**: Directly below velocity value
- **Font Size**: 3% of screen height
- **Font Weight**: Regular
- **Color**: Light Gray (#B0B0B0)
- **Format**:
  - Imperial: "miles per hour"
  - Metric: "kilometers per hour"
- **Alignment**: Center

#### 3. GPS Information Display (Bottom Half)
- **Position**: Three lines in bottom 50% of screen, starting at 5% from top of bottom half
- **Font Size**: 4% of screen height
- **Font Weight**: Regular
- **Font Style**: Proportional (for better fit on narrow screens)
- **Color**: Light Gray (#B0B0B0)
- **Background**: Black (#000000)
- **Alignment**: Left-aligned with 5% screen width padding
- **Vertical Spacing**: 1.5x font size between lines

**Line 1 - Latitude**:
```
Latitude: [value]
Format: "Latitude: XX.XXXX"
Precision: 4 decimal places
Example: "Latitude: 37.7749"
```

**Line 2 - Longitude**:
```
Longitude: [value]
Format: "Longitude: -XXX.XXXX"
Precision: 4 decimal places
Example: "Longitude: -122.4194"
```

**Line 3 - Altitude**:
```
Altitude: [value] [unit]
Format: "Altitude: %4.0f m" or "Altitude: %4.0f ft"
Precision: Whole numbers, fixed 4-digit width
Examples: "Altitude:  142 m", "Altitude: 1234 ft"
```

### Typography Details

#### Tabular Numbers vs Proportional
- **Velocity**: Tabular (monospaced digits)
  - Digits: Fixed width for alignment
  - Period: Narrow, proportional width
  - Result: Decimal point stays fixed, but periods don't look overly wide
- **GPS Data**: Fully proportional
  - All characters variable width
  - Allows text to fit better on narrow screens

### Character Morphing Animation

When any character changes, it animates through a horizontal compression/expansion.

#### Animation Timing
- **Total Duration**: 1.0 second
- **Phase 1** (0.0s → 0.5s): Old character compresses horizontally to 20% width
- **Phase 2** (0.5s → 1.0s): New character expands horizontally from 20% to 100% width
- **Character Switch**: At 0.5s (midpoint), display switches from old to new character
- **Easing**: Linear (no acceleration/deceleration)

#### Animation Algorithm
```
function animateCharacterChange(oldChar, newChar):
    // Phase 1: Compress old character (0.0 → 0.5)
    for t in 0.0 to 0.5 (step by frame time):
        progress = t / 0.5
        scaleX = 1.0 - (progress * 0.8)  // Compress from 100% to 20%
        displayChar = oldChar
        render(displayChar with scaleX)

    // Phase 2: Expand new character (0.5 → 1.0)
    for t in 0.5 to 1.0 (step by frame time):
        progress = (t - 0.5) / 0.5
        scaleX = 0.2 + (progress * 0.8)  // Expand from 20% to 100%
        displayChar = newChar
        render(displayChar with scaleX)
```

#### Visual Interpolation

The morphing is achieved purely by horizontal scaling:
1. **No vertical changes**: Characters maintain normal height
2. **No intermediate characters**: Direct old→new transition (no "|" character)
3. **Horizontal compression only**: ScaleX interpolates from 1.0 → 0.2 → 1.0

Example morphing "2" → "3":
```
Frame 0.0s:  "2"        (scaleX: 1.0, full width)
Frame 0.2s:  "2"        (scaleX: 0.68, compressed)
Frame 0.4s:  "2"        (scaleX: 0.28, very thin)
Frame 0.5s:  "3"        (scaleX: 0.2, very thin) ← character switches here
Frame 0.6s:  "3"        (scaleX: 0.36, expanding)
Frame 0.8s:  "3"        (scaleX: 0.72, wider)
Frame 1.0s:  "3"        (scaleX: 1.0, full width)
```

#### Multi-Character Changes

When multiple characters change simultaneously:
- **Synchronize timing**: All characters start/end animation together
- **Independent transitions**: Each character morphs individually
- **Visual effect**: Characters compress/expand in unison

Example: " 12.3" → " 13.4" (middle and last digits change)
```
At 0.0s: " 1 2 . 3"
At 0.5s: " 1 | . |"  (changed chars at thinnest point, switching)
At 1.0s: " 1 3 . 4"  (complete transition)
```

Note: The " 1 " (space-1-space) doesn't animate since it doesn't change.

### Update Frequency

#### GPS Updates
- **Rate**: Every 2 seconds
- **Trigger**: Timer-based polling of location service
- **What Updates**:
  - Velocity (always)
  - Latitude (always)
  - Longitude (always)
  - Altitude (always)
- **Implementation**:
  - iOS: Timer.scheduledTimer with 2.0 second interval
  - Android: Broadcast receiver from LocationTrackingService

#### Animation Frame Rate
- **Target**: 60 fps
- **Purpose**: Smooth character morphing
- **Implementation**:
  - iOS: Timer at 1/60 second interval updating currentTime state
  - Android: ValueAnimator with linear interpolation
- **Note**: Animation runs for 1 second after each GPS update, then screen is static until next update

### Special Cases

#### No GPS Lock
```
Velocity:    "  0.0"
Unit:        "miles per hour" or "kilometers per hour"
Latitude:    "Latitude: --"
Longitude:   "Longitude: --"
Altitude:    "Altitude:   --"
```

#### Initial State (Before First GPS)
Same as No GPS Lock - show zeros and dashes.

#### Rapid Changes
If a new GPS update arrives during active animation:
- Android: Cancel current animator, start fresh with new values
- iOS: State-based system naturally handles this - new animation states replace old ones
- Result: Smooth transition to new values without animation stacking

### Background
- **Color**: Pure Black (#000000)
- **Fills**: Entire screen

### Platform Implementation Notes

#### iOS
- Use `UILabel` or SwiftUI `Text` with `.font(.system(size: calculatedSize))`
- Implement morphing with Core Animation or custom drawing
- Update labels in response to location manager callbacks

#### Android
- Use `TextView` with dynamic text size
- Implement morphing with Property Animations or custom canvas drawing
- Update views in response to location listener callbacks

### Performance Considerations

- **Character Morphing**: Use GPU-accelerated transforms when possible
- **Text Layout**: Cache text measurements, only recalculate on size changes
- **Animation**: Use display link/choreographer for smooth 60fps rendering
- **Memory**: Reuse view objects, avoid allocating during animations

---

## Screen Management

### Full Screen Mode
- Hide status bar
- Hide navigation bar / system UI
- Use entire display area

### Keep Screen On
- Prevent device sleep
- Maintain maximum brightness (optional user setting)

### Exit Gesture
- **Tap anywhere** on screen exits visualization
- No other gestures or buttons visible
- Return to main screen immediately

---

## Performance Requirements

### Frame Rate
- Target: 60 fps
- Minimum: 30 fps
- Smooth color transitions with no stuttering

### GPS Update Rate
- Sample: Every 1 second
- Display: Update visualization immediately on each reading

### Battery Considerations
- Screen is main power draw (can't optimize this)
- GPS power usage is acceptable (required for functionality)
- Minimize CPU usage for rendering (simple shapes/colors)

---

## Testing Verification

### Visual Consistency Test
1. Configure both apps with identical thresholds
2. Simulate same GPS track on both platforms
3. Record video of both screens simultaneously
4. Verify colors and shapes match at each point

### Color Accuracy Test
1. Set speed to exact threshold values
2. Verify exact hex colors displayed
3. Test midpoint speeds, verify 50/50 blend

### Transition Smoothness Test
1. Gradually increase/decrease simulated speed
2. Verify smooth color gradients (no banding)
3. Verify no flicker or sudden jumps

---

## Color Reference Chart

For testing purposes, here are the exact color values:

### Data Visualization
| Element | Color | Hex | RGB | Use |
|---------|-------|-----|-----|-----|
| Background | Black | #000000 | (0, 0, 0) | Full screen |
| Velocity Text | White | #FFFFFF | (255, 255, 255) | Large display |
| GPS Info Text | Light Gray | #B0B0B0 | (176, 176, 176) | Location/altitude/sats |
| Stale Data | Gray | #808080 | (128, 128, 128) | 50% opacity fade |

---

## Implementation Checklist

### Flame Visualization
- [ ] Correct shader implementation (volumetric raymarching)
- [ ] Correct presets for each velocity bucket
- [ ] Smooth animation with time offset tracking
- [ ] Full screen mode (no UI visible)
- [ ] Keep screen on
- [ ] Tap to exit
- [ ] 60 fps rendering
- [ ] Updates on every GPS reading

### Data Visualization
- [ ] Correct text sizes and positioning
- [ ] Character morphing animation (1 second total)
- [ ] Two-phase morph: char→line (0.5s), line→char (0.5s)
- [ ] Synchronized multi-character transitions
- [ ] GPS data formatting (precision, units)
- [ ] No GPS / stale data handling
- [ ] Full screen mode (no UI visible)
- [ ] Keep screen on
- [ ] Tap to exit
- [ ] 60 fps morphing animation
- [ ] Updates on every GPS reading

### Yeti Visualization
- [ ] State machine implementation
- [ ] Video preloading and queueing
- [ ] Weighted random selection for same-state transitions
- [ ] Gradual one-step state transitions
- [ ] Full screen mode (no UI visible)
- [ ] Keep screen on
- [ ] Tap to exit
- [ ] Smooth video playback
- [ ] Updates on every GPS reading

---

## Testing Verification

### Data Visualization Tests

#### Character Morphing Test
1. Set up mock GPS that changes velocity from 12.0 to 13.0
2. Verify animation takes exactly 1.0 second
3. Verify middle digit morphs: "2" → "|" (0.5s) → "3" (1.0s)
4. Capture at 0.25s intervals, verify smooth interpolation

#### Multi-Character Test
1. Change velocity from 9.9 to 10.1
2. Verify all three characters animate simultaneously
3. Verify: "9.9" → "|||" (0.5s) → "10.1" (1.0s)

#### Stale Data Test
1. Stop GPS updates
2. Wait 5 seconds
3. Verify text fades to 50% opacity
4. Verify no morphing animations occur

#### No GPS Test
1. Turn off location services
2. Verify displays: "--.-", "No GPS Signal", "--", "0"
3. Verify no crash or error

---

## Future Enhancements

Potential additions (not yet implemented):

### All Visualizations
- [ ] Sound feedback on bucket transitions
- [ ] Haptic feedback for hard mode entry
- [ ] User-customizable color schemes

### Data Visualization
- [ ] Additional metrics (avg speed, max speed, duration)
- [ ] Graph of speed over time
- [ ] Configurable text color based on velocity bucket
- [ ] Export current screen as image
