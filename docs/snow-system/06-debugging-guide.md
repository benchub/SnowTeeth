# Debugging Guide

## Common Issues and Solutions

### Issue 1: Snow Not Following Letter Curves

**Symptoms**:
- Snow stacks appear flat on top of letters
- Curves like 'S' or arch of 'h' don't show contour
- All vertical stacks start at same Y position

**Root Cause**:
Using flat `bounds.minY` for all columns instead of sampling the path.

**Solution**:
Implement `findTopOfPathAt()` to vertically scan each X coordinate.

**File references**:
- iOS: `SnowEffect.swift:356-370`
- Android: `FallenSnow.kt:59-91`

**Verification**:
```swift
// Add debug logging in init
for i in 0..<min(3, width) {
    let x = offsetX + CGFloat(i)
    print("Sample at x=\(x): baselineY=\(baselineYs[i])")
}
```

Expected: Different Y values for different X positions on curved letters.

---

### Issue 2: Snow Accumulating on Button Corners

**Symptoms**:
- Snow appears in visually rounded corners
- Corners look square despite UI showing rounded

**Root Cause**:
Button bounds are rectangular; no path available to exclude corners.

**Solution**:
Manually exclude corner zones by setting baseline far below screen.

**iOS** (`SnowEffect.swift:346-354`):
```swift
let cornerRadius: CGFloat = 15.0
if x < bounds.minX + cornerRadius || x > bounds.maxX - cornerRadius {
    self.baselineYs[i] = bounds.maxY + 1000
} else {
    self.baselineYs[i] = bounds.minY
}
```

**Android** (`FallenSnow.kt:42-55`):
```kotlin
val cornerRadius = 15f * 3  // 15dp scaled for xhdpi
```

**Tuning**: Adjust `cornerRadius` to match actual button corner radius in your UI.

---

### Issue 3: Snow Falling Through Letters

**Symptoms**:
- Snow passes through thin parts of letters (e.g., arch of 'h', top of 't')
- Most of letter works, but specific thin areas fail

**Root Cause**:
Path sampling step too coarse (e.g., 0.5 pixels) missing thin strokes.

**Example**: Letter 'h' arch is ~1 pixel thick. With 0.5px step:
```
y=154.0: Outside path
y=154.5: Outside path (missed the 1px arch!)
y=155.0: Inside hollow of 'h' (wrong!)
```

**Solution**:
Reduce sampling step to 0.1 pixels.

```swift
let step: CGFloat = 0.1  // NOT 0.5
```

**Trade-off**:
- 0.1px: Catches all features, 5× slower initialization (~0.5ms per surface)
- 0.5px: Misses thin features, faster (~0.1ms per surface)

For initialization that happens once, accuracy is worth the cost.

**Verification**:
Test on letters with thin features: h, t, i, l, f

---

### Issue 4: Letter Position Mismatch ("Sno" Good, "wTeeth" Wrong)

**Symptoms**:
- First few letters have accurate collision detection
- Later letters increasingly misaligned
- Collision detection thinks letter is at different position than rendered

**Root Cause**:
Attempting to calculate text layout using NSString.size(), CoreText, or manual calculations. SwiftUI's text layout doesn't match any of these.

**Failed Approaches**:
```swift
// ❌ Doesn't work
let textSize = (text as NSString).size(withAttributes: [.font: font])
let startX = (screenWidth - textSize.width) / 2

// ❌ Doesn't work
let ctLine = CTLineCreateWithAttributedString(attributedString)
let width = CTLineGetTypographicBounds(ctLine, nil, nil, nil)

// ❌ Doesn't work
let frame = geometryReader.frame(in: .named("space"))
// Then trying to calculate individual letter positions from frame.minX
```

**Solution**:
Per-letter rendering with GeometryReader per letter.

**iOS** (`ContentView.swift:35-52`):
```swift
HStack(spacing: 0) {
    ForEach(Array("SnowTeeth".enumerated()), id: \.offset) { index, char in
        Text(String(char))
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        captureLetterBounds(char: char, index: index, geometry: geo)
                    }
                }
            )
    }
}
```

See `03-per-letter-rendering.md` for full details.

**Verification**:
```swift
print("Letter '\(char)' at index \(index): frame=\(frame)")
```

Each letter should have measured position, not calculated.

---

### Issue 5: "Floating" Snow Above Letters

**Symptoms**:
- Snow appears stuck in mid-air above letters
- Height-map visualizations show stacks not touching surface
- Gap of several pixels between snow and letter

**Root Causes**:

**Cause A: Collision Buffer Too Large**
```swift
// ❌ 20 pixels is too large
return y >= snowTop && y <= baseline + 20
```

**Solution**: Reduce to 3 pixels
```swift
// ✅ 3 pixels allows for sub-pixel positioning
return y >= snowTop && y <= baseline + 3
```

**Cause B: Checking Snowflake Bottom Instead of Center**
```swift
// ❌ Checking bottom edge
let checkY = snowflake.position.y + snowflake.size / 2
if surfaceMap.collides(x: snowflake.position.x, y: checkY) { ... }
```

**Solution**: Check at center
```swift
// ✅ Check at center of snowflake
if surfaceMap.collides(x: snowflake.position.x, y: snowflake.position.y) { ... }
```

**Cause C: Rendering Snowflake with Top-Left at Position**
```swift
// ❌ iOS: Drawing circle with top-left at position
let rect = CGRect(x: position.x, y: position.y, width: size, height: size)
```

**Solution**: Center the rendering
```swift
// ✅ iOS: Center the circle at position
let halfSize = size / 2
let rect = CGRect(x: position.x - halfSize, y: position.y - halfSize, width: size, height: size)
```

**Note**: Android's `drawCircle(cx, cy, radius)` automatically centers, so no issue there.

**Verification**:
Visual inspection - snow should touch the surface with no visible gap.

---

### Issue 6: Letter Boundary Gaps or Overlaps

**Symptoms**:
- Snow falls through tiny gaps between letters
- Snow stacks overlap at letter boundaries
- Adjacent letters show coordinate conflicts in logs

**Root Cause**:
Using floor for both start and end X, or ceil for both, creates gaps or overlaps.

```swift
// ❌ Creates 1-pixel gap between adjacent surfaces
let startX = Int(floor(bounds.minX))
let endX = Int(floor(bounds.maxX))

// ❌ Creates 1-pixel overlap
let startX = Int(ceil(bounds.minX))
let endX = Int(ceil(bounds.maxX))
```

**Solution**: Use ceil for start, floor for end
```swift
// ✅ Sample only pixels actually inside bounds
let startX = Int(ceil(bounds.minX))
let endX = Int(floor(bounds.maxX))
let width = max(0, endX - startX + 1)
```

**Example**:
```
Letter A bounds: [10.3, 30.7]
Letter B bounds: [30.7, 50.2]

Letter A samples: ceil(10.3)=11 to floor(30.7)=30  (pixels 11-30)
Letter B samples: ceil(30.7)=31 to floor(50.2)=50  (pixels 31-50)
No gap, no overlap! ✅
```

**Verification**:
```swift
print("Letter \(id): startX=\(startX), endX=\(endX), width=\(width)")
```

Adjacent letters should have endX[i] + 1 == startX[i+1].

---

### Issue 7: Android Baseline Y Mismatch

**Symptoms**:
- Android: Snow stacks appear below letters (halfway to next UI element)
- iOS: Works correctly
- Paths seem to be generated at wrong vertical position

**Root Cause**:
Passing top Y to `getTextPath()` which expects baseline Y.

```kotlin
// ❌ Wrong: position.y is top of frame
paint.getTextPath(charString, 0, 1, currentX, position.y, path)
```

**Solution**: Calculate baseline Y
```kotlin
// ✅ Correct: Add ascent to get baseline
val fontMetrics = paint.fontMetrics
val ascent = -fontMetrics.ascent
val baselineY = position.y + ascent
paint.getTextPath(charString, 0, 1, currentX, baselineY, path)
```

**File**: `MainActivity.kt:274-277`

**Verification**:
```kotlin
Log.d("TextPath", "Top Y: ${position.y}, Baseline Y: $baselineY, Ascent: $ascent")
```

Baseline should be ~30-40 pixels below top for typical fonts.

---

### Issue 8: Android Paths Not Saved

**Symptoms**:
- All letters show `hasPath=false` or `path.isEmpty=true` in logs
- Snow doesn't follow contours on Android, but works on iOS
- First letter works, rest are empty

**Root Cause**:
Reusing single Path object and calling `reset()` in loop.

```kotlin
// ❌ Reuses same path object
val path = Path()
for (char in text) {
    path.reset()  // Clears previous letter!
    paint.getTextPath(charString, 0, 1, currentX, baselineY, path)
    results.add(Triple(id, bounds, path))  // All point to same path
}
```

**Solution**: Create new Path per letter
```kotlin
// ✅ New path for each letter
for (char in text) {
    val path = Path()  // Inside loop!
    paint.getTextPath(charString, 0, 1, currentX, baselineY, path)
    results.add(Triple(id, bounds, path))
}
```

**File**: `LetterBoundsCalculator.kt:35`

**Verification**:
```kotlin
val boundsRect = RectF()
path.computeBounds(boundsRect, true)
Log.d("Path", "Letter '$char': isEmpty=${path.isEmpty}, bounds=$boundsRect")
```

Each letter should have non-empty path.

---

### Issue 9: Tiny Snow on Android

**Symptoms**:
- Snow particles barely visible on Android
- iOS snow looks normal size
- Android particles are ~2-3 pixels

**Root Cause**:
Not scaling for screen density. Using raw pixel values that look tiny on high-DPI screens.

```kotlin
// ❌ 2-3.5 pixels is tiny on xhdpi (480dpi)
val size = Random.nextFloat() * 1.5f + 2f
```

**Solution**: Scale by density factor
```kotlin
// ✅ Scale by 3× for xhdpi screens
val baseSize = Random.nextFloat() * 1.5f + 2f  // 2-3.5 dp
val size = baseSize * 3f  // 6-10.5 pixels

// Better: Use actual density
val density = context.resources.displayMetrics.density
val size = baseSize * density
```

**File**: `SnowEffect.kt:238-239`

**Verification**:
```kotlin
Log.d("Snow", "Base size: $baseSize dp, Scaled size: $size px, Density: $density")
```

On xhdpi (density=2.0), size should be ~4-7 pixels.

---

### Issue 10: Compilation Errors (Kotlin)

**Symptoms**:
```
Unresolved reference: pow
Unresolved reference: Random
```

**Root Cause**:
Missing imports in Kotlin files.

**Solution**: Add imports
```kotlin
import kotlin.math.pow
import kotlin.random.Random
```

Also fix pow syntax:
```kotlin
// ❌ Function call syntax
val probability = kotlin.math.pow(1.0f - excess/10, 3.0f)

// ✅ Extension function syntax
val probability = (1.0f - excess/10).pow(3.0f)
```

**File**: `FallenSnow.kt:7-8`

---

## Debugging Tools

### Visual Height-Map Rendering

Enable to see snow columns:

**iOS** (`SnowEffectView.swift:53-68`):
```swift
// Draw fallen snow height-maps
for (_, surfaceMap) in snowEffect.surfaceSnowMaps {
    for (x, height, baseline) in surfaceMap.getHeights() {
        if height > 0 {
            context.fill(Rectangle().path(in: rect), with: .color(.white))
        }
    }
}
```

**Android**: Similar in `SnowParticleView.kt:98-113`

Shows vertical white bars where snow has accumulated.

### Logging Points

**Initialization**:
```swift
print("🎯 Setting snow effect targets: \(bounds.count) total bounds")
print("  - \(id): bounds=\(bounds), hasPath=\(path != nil)")
```

**Path Sampling**:
```swift
print("Sample at x=\(x): topY=\(topY), bounds.top=\(bounds.top)")
```

**Collision Detection**:
```swift
print("Collision at x=\(x), y=\(y): baseline=\(baseline), snowTop=\(snowTop)")
```

**Particle Stats** (periodic):
```swift
print("📊 Particles - Falling: \(falling), Sliding: \(sliding), Total: \(total)")
```

### Performance Profiling

**Measure path sampling**:
```swift
let start = Date()
for i in 0..<width {
    baselineYs[i] = findTopOfPathAt(x: offsetX + CGFloat(i), path: path, bounds: bounds)
}
let elapsed = Date().timeIntervalSince(start) * 1000
print("⏱️ Path sampling took \(elapsed)ms for width=\(width)")
```

Expected: 0.1-0.5ms per surface with 0.1px step.

### Visual Debugging Checklist

- [ ] Enable height-map rendering
- [ ] Verify snow touches letter surfaces (no gaps)
- [ ] Check contour following on 'S' and 'h'
- [ ] Confirm no accumulation on button corners
- [ ] Test thin features: h arch, t top, i dot
- [ ] Check letter boundaries (no gaps/overlaps)
- [ ] Verify probabilistic heights (varied, not uniform)
- [ ] Watch for erosion (stacks should shrink over time)
