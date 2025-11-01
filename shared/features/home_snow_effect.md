# Home Page Snow Effect

## Overview

A festive snow effect for the home page featuring falling snow that accumulates on UI elements and slides off when the device is rotated. Inspired by xSnow, this creates a delightful seasonal experience.

---

## Feature Requirements

### Visual Elements

1. **Background**
   - Dark grey background (#2C2C2C or similar)
   - Replaces current white/system background

2. **Falling Snow**
   - Continuous snowflakes falling from top of screen
   - Varies in size, speed, and opacity for depth effect
   - Gentle side-to-side drift as they fall

3. **Snow Accumulation**
   - Snow lands and sticks to:
     - Individual letters in "SnowTeeth" title (per-letter collision)
     - All buttons (Configuration, Visualization, Stats, Share GPX, Start/Stop Tracking)
   - Accumulated snow is visible on top of these elements

4. **Rotation Behavior**
   - When device rotates, all accumulated snow is reset/cleared
   - Simplified from original slide-off animation for better performance
   - Snow continues to fall and accumulate based on new screen orientation

5. **Santa Animation**
   - Santa flies across screen horizontally every 30-60 seconds
   - Moves from right to left (or left to right randomly)
   - Small sleigh silhouette or emoji (🎅 or 🛷)
   - Passes in front of snow (higher z-index)

---

## Implementation Strategy

### Phase 1: Core Logic with Unit Tests

Build testable algorithm components independent of UI:

#### Components to Test

1. **CollisionDetector**
   - Detects if point (snowflake) intersects with rectangle (letter/button bounds)
   - Handles edge cases (exact boundaries, corners)

2. **LetterBoundsCalculator**
   - Given text "SnowTeeth", returns array of bounding rectangles for each character
   - Accounts for font size, spacing, kerning

3. **Particle State Machine**
   - States: `falling`, `stuck`, `sliding`, `gone`
   - Transitions based on collisions and rotation events

4. **GravityCalculator**
   - Converts device orientation to gravity direction vector
   - Calculates slide direction for stuck particles

#### Test Strategy

**iOS Tests** (XCTest framework):
```swift
class SnowEffectTests: XCTestCase {
    func testSnowflakeCollidesWithLetterTop()
    func testSnowflakePassesThroughGap()
    func testLetterBoundsForSnowTeeth()
    func testParticleTransitionsToStuck()
    func testRotationTriggersSlide()
    func testSlideDirectionFromPortraitToLandscape()
}
```

**Android Tests** (JUnit framework):
```kotlin
class SnowEffectTest {
    @Test fun snowflakeCollidesWithLetterTop()
    @Test fun snowflakePassesThroughGap()
    @Test fun letterBoundsForSnowTeeth()
    @Test fun particleTransitionsToStuck()
    @Test fun rotationTriggersSlide()
    @Test fun slideDirectionFromPortraitToLandscape()
}
```

**Running Tests:**
- iOS: `xcodebuild test -scheme SnowTeeth -destination 'platform=iOS Simulator,name=iPhone 17'`
- Android: `./gradlew test`

**Success Criteria:** All tests passing before moving to Phase 2

### Phase 2: UI Integration

Once core logic is tested and working:

1. Add dark grey background to ContentView (iOS) / activity_main.xml (Android)
2. Add snow particle rendering layer
3. Wire up tested collision detection
4. Add animation loop for falling snow
5. Connect rotation event handlers
6. Add Santa periodic animation

---

## Technical Specifications

### Particle System

**Snowflake Properties:**
```swift
struct Snowflake {
    var position: CGPoint
    var velocity: CGVector
    var size: CGFloat        // 2-8 points
    var opacity: Float       // 0.3-1.0
    var state: ParticleState // falling, stuck, sliding, gone
    var stuckTo: String?     // letterIndex or buttonId
}

enum ParticleState {
    case falling
    case stuck(to: SurfaceId)
    case sliding(direction: CGVector)
    case gone
}
```

**Particle Behavior:**
- Spawn rate: 50-100 particles per interval (every 150ms = ~200-400 particles/second)
- Max falling particles: 300 (light to moderate snowfall density)
- Fall speed: 20-50 points/second (varies per particle)
- Wind-based horizontal movement: -40 to +40 points/second (global wind direction)
- Wind changes every 5 seconds with occasional gusts (15% chance of 1.5x wind)

### Collision Detection

**Algorithm:**
```
For each falling particle:
    For each collision target (letter/button):
        If particle.y + particle.size >= target.top:
            If particle.x is within target.left to target.right:
                particle.state = .stuck(to: target.id)
                particle.position.y = target.top - particle.size
                break
```

**Optimization:**
- Sort collision targets by y-position (top to bottom)
- Early exit once particle passes all targets
- Only check falling particles (not stuck/sliding)

### Letter Bounds Detection

**iOS Approach:**
```swift
func getLetterBounds(text: String, font: UIFont, position: CGPoint) -> [CGRect] {
    let attributedString = NSAttributedString(string: text, attributes: [.font: font])
    let ctLine = CTLineCreateWithAttributedString(attributedString)
    let runs = CTLineGetGlyphRuns(ctLine)

    var bounds: [CGRect] = []
    for i in 0..<text.count {
        let glyphRange = CFRange(location: i, length: 1)
        let glyphBounds = CTLineGetBoundsWithOptions(ctLine, .useGlyphPathBounds)
        // Calculate individual letter rect
        bounds.append(rect)
    }
    return bounds
}
```

**Android Approach:**
```kotlin
fun getLetterBounds(text: String, paint: Paint, x: Float, y: Float): List<RectF> {
    val bounds = mutableListOf<RectF>()
    var currentX = x

    for (char in text) {
        val charBounds = Rect()
        paint.getTextBounds(char.toString(), 0, 1, charBounds)
        bounds.add(RectF(
            currentX,
            y + charBounds.top,
            currentX + charBounds.width(),
            y + charBounds.bottom
        ))
        currentX += paint.measureText(char.toString())
    }
    return bounds
}
```

### Rotation Handling

**Detecting Rotation:**
- iOS: Listen to `UIDevice.orientationDidChangeNotification`
- Android: Override `onConfigurationChanged()`

**Reset Behavior:**
```
On rotation event:
    // Clear all accumulated snow from all surfaces
    for each surfaceSnowMap:
        surfaceSnowMap.reset()

    // Remove all stuck particles (if any tracked)
    snowflakes.removeAll { particle.state == .stuck }
```

**Implementation Notes:**
- Simplified from original slide-off animation design
- Provides cleaner user experience and better performance
- Snow immediately starts accumulating again in new orientation
- Falling particles continue their motion (not affected by rotation)

### Animation Loop

**Frame Rate:** 60 FPS (16.67ms per frame)

**Per Frame:**
1. Update all particle positions based on state
2. Check for collisions (falling particles only)
3. Remove offscreen particles (state = .gone)
4. Spawn new particles if count < max
5. Render all particles
6. Render Santa if active

**iOS:** Use `CADisplayLink` or SwiftUI `TimelineView`
**Android:** Use `Choreographer` or custom View with `invalidate()`

### Santa Animation

**Properties:**
```swift
struct Santa {
    var position: CGPoint
    var velocity: CGVector  // 100-150 points/second
    var isActive: Bool
    var nextAppearanceTime: TimeInterval
}
```

**Behavior:**
- Appears every 30-60 seconds (random)
- Starts offscreen (left or right, random)
- Flies horizontally across screen
- Size: 40-60 points
- Z-index: Above snow, below UI text

**Asset:**
- Use SF Symbol "🎅" or "sled.fill" on iOS
- Use emoji "🎅" or custom drawable on Android

---

## Performance Considerations

### Particle Count Limits
- Max 200 particles simultaneously
- Remove offscreen particles immediately
- Limit stuck particles per target (max 10 per letter/button)

### Collision Check Optimization
- Only check falling particles against targets
- Sort targets top-to-bottom, early exit
- Use spatial partitioning if needed (unlikely with small particle count)

### Memory Management
- Reuse particle objects (object pool)
- Batch rendering calls
- Use hardware acceleration (Metal on iOS, OpenGL on Android)

### Battery Impact
- Animation only runs when home screen is visible
- Pause when app is backgrounded
- Consider "reduced motion" accessibility setting

---

## Accessibility

### Respect System Settings
- Check `UIAccessibility.isReduceMotionEnabled` (iOS)
- Check `Settings.Global.TRANSITION_ANIMATION_SCALE` (Android)
- If motion is reduced: disable snow effect, keep dark background

### Alternative Experience
- Provide setting to disable effect
- Keep functionality fully accessible without effect
- Ensure text contrast on dark grey background

---

## Testing Checklist

### Unit Tests (Phase 1)
- [ ] Collision detection math verified
- [ ] Letter bounds calculation accurate
- [ ] Particle state transitions correct
- [ ] Gravity direction calculated properly
- [ ] Edge cases handled (boundaries, corners, gaps)

### Integration Tests (Phase 2)
- [ ] Snow falls continuously
- [ ] Snow sticks to letters correctly
- [ ] Snow sticks to buttons correctly
- [ ] Per-letter collision works for all letters
- [ ] Rotation triggers slide-off
- [ ] Particles slide in correct direction
- [ ] Santa appears periodically
- [ ] Performance acceptable (60 FPS)

### Device Testing
- [ ] iPhone (portrait and landscape)
- [ ] iPad (all orientations)
- [ ] Android phone (various screen sizes)
- [ ] Android tablet
- [ ] Dark background looks good
- [ ] Text remains readable

---

## Constants

```swift
// Particle system
let spawnInterval = 0.15         // seconds (150ms)
let particlesPerSpawn = 50...100 // particles spawned per interval
let maxFallingParticles = 300    // maximum falling particles on screen
let snowSizeRange = 2.0...3.5    // points (iOS), 6-10.5 pixels (Android at 3x density)
let snowOpacityRange = 0.6...1.0
let fallSpeedRange = 20.0...50.0 // points per second
let windRange = -40.0...40.0     // points per second (global wind direction)
let windChangeInterval = 5.0     // seconds between wind direction changes
let gustProbability = 0.15       // 15% chance of 1.5x wind gust

// Snow accumulation (see snow_accumulation.md)
let comfortableHeight_regular = 5.0   // pixels
let maxHeight_regular = 15.0          // pixels
let comfortableHeight_ground = 15.0   // pixels (3x)
let maxHeight_ground = 45.0           // pixels (3x)

// Collision
let collisionBuffer = 3.0        // pixels below surface for collision detection

// Animation
let targetFrameRate = 60.0       // FPS

// Santa
let santaIntervalRange = 30.0...60.0  // seconds
let santaSpeed = 120.0           // points per second
let santaSize = 50.0             // points

// Colors
let backgroundColor = "#2C2C2C"
let snowColor = "#FFFFFF"
```

---

## File Structure

### iOS
```
iOS/SnowTeeth/
├── Effects/
│   ├── SnowEffect.swift           (main coordinator)
│   ├── Snowflake.swift            (particle model)
│   ├── CollisionDetector.swift    (testable collision logic)
│   ├── LetterBoundsCalculator.swift
│   ├── GravityCalculator.swift
│   └── SantaAnimator.swift
├── Views/
│   ├── SnowEffectView.swift      (SwiftUI rendering)
│   └── ContentView.swift          (add background + snow layer)
└── Tests/
    └── SnowEffectTests.swift      (unit tests)
```

### Android
```
android/app/src/main/java/com/snowteeth/app/
├── effects/
│   ├── SnowEffect.kt              (main coordinator)
│   ├── Snowflake.kt               (particle model)
│   ├── CollisionDetector.kt       (testable collision logic)
│   ├── LetterBoundsCalculator.kt
│   ├── GravityCalculator.kt
│   └── SantaAnimator.kt
├── view/
│   ├── SnowEffectView.kt          (custom View for rendering)
│   └── MainActivity.kt             (add snow layer)
└── test/
    └── SnowEffectTest.kt          (unit tests)
```

---

## Implementation Status

1. ✅ Write specification (this document)
2. ✅ Implement testable core logic (iOS)
3. ✅ Write and run unit tests (iOS)
4. ✅ Fix issues until all tests pass
5. ✅ Integrate into iOS UI
6. ✅ Visual testing and refinement (iOS)
7. ✅ Implement testable core logic (Android)
8. ✅ Write and run unit tests (Android)
9. ✅ Fix issues until all tests pass
10. ✅ Integrate into Android UI
11. ✅ Visual testing and refinement (Android)
12. ✅ Add Santa animation (both platforms)
13. ✅ Performance testing and optimization
14. ⚠️ Accessibility testing (partially complete)

**Current Status:** Feature is fully implemented on both iOS and Android platforms with height-map based snow accumulation, collision detection, and festive effects. Both implementations use identical algorithms.

---

## Future Enhancements (Optional)

- Multiple Santa characters with different speeds
- Snowflakes with unique shapes (not just circles)
- Wind effect (all snow drifts in one direction)
- Melting animation (snow gradually fades after landing)
- Sound effects (jingle bells when Santa appears)
- Different weather patterns (light snow, blizzard mode)
- Seasonal toggle (enable/disable in settings)
