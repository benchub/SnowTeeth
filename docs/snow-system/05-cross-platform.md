# Cross-Platform Implementation Details

## Overview

The snow system achieves identical behavior on iOS and Android despite different graphics APIs and text rendering systems. This document details the platform-specific implementations and how they achieve parity.

## Platform Comparison

| Feature | iOS | Android |
|---------|-----|---------|
| **Language** | Swift | Kotlin |
| **Graphics** | SwiftUI Canvas + CoreGraphics | Custom View + Android Canvas |
| **Text Paths** | CoreText | Paint.getTextPath |
| **Path Testing** | CGPath.contains() | Region.contains() |
| **Coordinate Origin** | Top-left | Top-left |
| **Y-Axis Direction** | Down (positive) | Down (positive) |
| **Text Baseline** | CoreText needs flip | Paint expects baseline |

## Text Path Generation

### iOS: CoreText Approach

**File**: `LetterBoundsCalculator.swift:24-96`

```swift
let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)

for (index, char) in text.enumerated() {
    let charString = String(char)
    guard let unichar = charString.utf16.first else { continue }

    var character = unichar
    var glyph: CGGlyph = 0

    // Get glyph for character
    let success = withUnsafeMutablePointer(to: &character) { charPtr in
        withUnsafeMutablePointer(to: &glyph) { glyphPtr in
            CTFontGetGlyphsForCharacters(ctFont, charPtr, glyphPtr, 1)
        }
    }

    guard success else { continue }

    // Get path for glyph
    if let path = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
        let pathBounds = path.boundingBox
        let ascent = CTFontGetAscent(ctFont)

        // Transform to world coordinates
        var transform = CGAffineTransform(translationX: currentX, y: position.y + ascent)
        transform = transform.scaledBy(x: 1, y: -1)  // Flip Y axis (CoreText Y+ is up)
        let worldPath = path.copy(using: &transform)

        let bounds = CGRect(
            x: currentX + pathBounds.minX,
            y: position.y + (ascent - pathBounds.maxY),
            width: pathBounds.width,
            height: pathBounds.height
        )

        results.append((id: "letter_\(index)", bounds, worldPath))

        // Advance
        var advance: CGSize = .zero
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)
        currentX += advance.width
    }
}
```

**Key points**:
- CoreText uses baseline origin with Y+ going up
- Must flip Y-axis with `scaledBy(x: 1, y: -1)`
- `CTFontCreatePathForGlyph` returns path in glyph space
- Transform translates and flips to screen coordinates
- `CTFontGetAdvancesForGlyphs` provides proper horizontal spacing

### Android: Paint.getTextPath Approach

**File**: `LetterBoundsCalculator.kt:16-63`

```kotlin
val paint = Paint().apply {
    textSize = 34f * 3f  // Scale for screen density
    typeface = Typeface.DEFAULT_BOLD
}

for ((index, char) in text.withIndex()) {
    val charString = char.toString()

    // Create separate path for each letter
    val path = Path()

    // Get font metrics
    val fontMetrics = paint.fontMetrics
    val ascent = -fontMetrics.ascent
    val descent = fontMetrics.descent

    // getTextPath expects baseline Y coordinate
    val baselineY = position.y + ascent

    // Generate path in world coordinates
    paint.getTextPath(charString, 0, 1, currentX, baselineY, path)

    // Measure bounds
    val pathBounds = RectF()
    path.computeBounds(pathBounds, true)

    // Get text width for advance
    val widths = FloatArray(1)
    paint.getTextWidths(charString, widths)
    val advance = widths[0]

    val bounds = RectF(
        currentX + pathBounds.left,
        position.y,  // Top of text frame
        currentX + pathBounds.right,
        position.y + ascent + descent
    )

    results.add(Triple("letter_$index", bounds, path))
    currentX += advance
}
```

**Key points**:
- Android's Paint.getTextPath expects baseline Y, not top
- Must calculate: `baselineY = position.y + ascent`
- No Y-axis flip needed (Paint already uses screen coordinates)
- `paint.getTextWidths()` provides advance width
- Path is generated directly in screen coordinates

### Key Difference: Baseline vs Top

**iOS**:
```swift
// position.y is the top of the text frame
// CoreText needs translation to baseline
let baselineY = position.y + ascent
transform = CGAffineTransform(translationX: currentX, y: baselineY)
transform = transform.scaledBy(x: 1, y: -1)  // Then flip Y
```

**Android**:
```kotlin
// position.y is the top of the text frame
// Paint.getTextPath expects baseline Y directly
val baselineY = position.y + ascent
paint.getTextPath(charString, 0, 1, currentX, baselineY, path)
// No flip needed - already in screen coordinates
```

## Path Collision Testing

### iOS: CGPath.contains()

**File**: `SnowEffect.swift:356-370`

```swift
private func findTopOfPathAt(x: CGFloat, path: CGPath, bounds: CGRect) -> CGFloat {
    if x < bounds.minX || x > bounds.maxX {
        return bounds.maxY + 1000
    }

    let step: CGFloat = 0.1
    for y in stride(from: bounds.minY, through: bounds.maxY, by: step) {
        if path.contains(CGPoint(x: x, y: y)) {
            return y  // Found top of surface
        }
    }
    return bounds.maxY + 1000
}
```

**API**: `CGPath.contains(CGPoint, using: .winding, transform: nil)`
- Built-in hit testing
- Uses winding rule by default
- No setup required

### Android: Region.contains()

**File**: `FallenSnow.kt:59-91`

```kotlin
private fun findTopOfPathAt(x: Float, path: Path, bounds: RectF): Float {
    if (x < bounds.left || x > bounds.right) {
        return bounds.bottom + 1000f
    }

    val step = 0.1f
    var y = bounds.top

    // Set up region for path testing
    val region = Region()
    val pathBounds = Region(
        bounds.left.toInt(),
        bounds.top.toInt(),
        bounds.right.toInt(),
        bounds.bottom.toInt()
    )
    region.setPath(path, pathBounds)

    while (y <= bounds.bottom) {
        if (region.contains(x.toInt(), y.toInt())) {
            return y  // Found top of surface
        }
        y += step
    }
    return bounds.bottom + 1000f
}
```

**API**: `Region.setPath(Path, Region)` + `Region.contains(int, int)`
- Requires Region setup with clip bounds
- Must convert path to region first
- Contains() takes integers only
- More verbose but similar behavior

### Parity Notes

Both implementations:
- Use 0.1 pixel step size for fine sampling
- Return `bounds.max + 1000` for out-of-bounds or no intersection
- Check if X is within bounds before sampling
- Iterate from top to bottom to find first intersection

## Rendering

### iOS: SwiftUI Canvas

**File**: `SnowEffectView.swift:15-68`

```swift
Canvas { context, size in
    // Draw snowflakes
    for snowflake in snowEffect.snowflakes {
        let halfSize = snowflake.size / 2
        let rect = CGRect(
            x: snowflake.position.x - halfSize,
            y: snowflake.position.y - halfSize,
            width: snowflake.size,
            height: snowflake.size
        )

        context.fill(
            Circle().path(in: rect),
            with: .color(.white.opacity(Double(snowflake.opacity)))
        )
    }

    // Draw height-maps
    for (_, surfaceMap) in snowEffect.surfaceSnowMaps {
        for (x, height, baseline) in surfaceMap.getHeights() {
            if height > 0 {
                let rect = CGRect(x: x, y: baseline - height, width: 1, height: height)
                context.fill(Rectangle().path(in: rect), with: .color(.white))
            }
        }
    }
}
.ignoresSafeArea()
.allowsHitTesting(false)
```

**Key features**:
- SwiftUI's Canvas API (declarative)
- Circle() and Rectangle() are Shape types
- `.fill()` with color and opacity
- Automatically centered when drawing Circle in rect

### Android: Custom View with onDraw

**File**: `SnowParticleView.kt:64-113`

```kotlin
override fun onDraw(canvas: Canvas) {
    super.onDraw(canvas)

    // Draw snowflakes
    for (snowflake in snowEffect.getSnowflakes()) {
        paint.alpha = (snowflake.opacity * 255).toInt()
        canvas.drawCircle(
            snowflake.position.x,
            snowflake.position.y,
            snowflake.size / 2f,
            paint
        )
    }

    // Draw height-maps
    for ((_, surfaceMap) in snowEffect.getSurfaceSnowMaps()) {
        for ((x, height, baseline) in surfaceMap.getHeights()) {
            if (height > 0f) {
                canvas.drawRect(
                    x,
                    baseline - height,
                    x + 1f,
                    baseline,
                    paint
                )
            }
        }
    }
}
```

**Key features**:
- Android's Canvas API (imperative)
- `drawCircle(cx, cy, radius, paint)` - center and radius
- `drawRect(left, top, right, bottom, paint)`
- Paint alpha must be set per draw call

### Rendering Differences

| Aspect | iOS | Android |
|--------|-----|---------|
| **Circle drawing** | Circle().path(in: rect) | drawCircle(cx, cy, radius) |
| **Centering** | Automatic with rect | Manual (cx, cy) |
| **Opacity** | Per-color (.opacity()) | Per-paint (paint.alpha) |
| **Coordinates** | Shape in rect | Direct coordinates |

## Screen Density Handling

### iOS: Points vs Pixels

iOS uses **points**, which automatically scale based on screen density:
- @1x: 1 point = 1 pixel (non-Retina)
- @2x: 1 point = 2 pixels (Retina)
- @3x: 1 point = 3 pixels (Retina HD)

**No manual scaling needed** - SwiftUI handles it automatically:
```swift
let size = Random.nextFloat() * 1.5 + 2.0  // 2-3.5 points
// Automatically becomes 4-7 pixels on @2x, 6-10.5 pixels on @3x
```

### Android: Manual Density Scaling

Android uses **pixels**, must manually scale for screen density:
- mdpi: 1dp = 1px (baseline)
- hdpi: 1dp = 1.5px
- xhdpi: 1dp = 2px
- xxhdpi: 1dp = 3px
- xxxhdpi: 1dp = 4px

**Manual scaling required**:
```kotlin
val baseSize = Random.nextFloat() * 1.5f + 2f  // 2-3.5 dp
val size = baseSize * 3f  // Scale to pixels for xhdpi (6-10.5 pixels)
```

For proper density handling, should use:
```kotlin
val density = context.resources.displayMetrics.density
val size = baseSize * density
```

## Button Corner Handling

Both platforms need to prevent accumulation on rounded corners:

### iOS
```swift
let cornerRadius: CGFloat = 15.0  // In points (auto-scales)
if x < bounds.minX + cornerRadius || x > bounds.maxX - cornerRadius {
    self.baselineYs[i] = bounds.maxY + 1000
} else {
    self.baselineYs[i] = bounds.minY
}
```

### Android
```kotlin
val cornerRadius = 15f * 3  // 15dp × 3 for xhdpi = 45px
val leftEdge = bounds.left + cornerRadius
val rightEdge = bounds.right - cornerRadius

if (x < leftEdge || x > rightEdge) {
    bounds.bottom + 1000f
} else {
    bounds.top
}
```

**Note**: The `* 3` multiplier should ideally be replaced with proper density calculation.

## Update Loop Timing

Both platforms use similar timing:

### iOS
```swift
// Called via TimelineView(.animation(minimumInterval: 1.0/60.0))
let currentTime = Date().timeIntervalSince1970 * 1000
let deltaTime = (currentTime - lastUpdateTime) / 1000  // To seconds
```

### Android
```kotlin
// Called via invalidate() in onDraw
val currentTime = System.currentTimeMillis()
val deltaTime = (currentTime - lastUpdateTime) / 1000f  // To seconds
```

Both achieve ~60 FPS with delta-time based physics.

## Testing Cross-Platform Parity

### Visual Verification Checklist

- [ ] Snow accumulates at same rate on both platforms
- [ ] Height-map stacks match visually (same positions and heights)
- [ ] Contour following works identically (curves of 'S', arch of 'h')
- [ ] Button corners have no accumulation on both
- [ ] Probabilistic stacking produces similar distributions
- [ ] Random erosion creates similar dynamic effects
- [ ] Particle sizes appear visually similar
- [ ] Opacity and rendering quality match

### Measurement Points

For the "SnowTeeth" text:
1. Baseline Y for 'S' at x=start should match
2. Baseline Y for 'h' arch (mid-letter) should match
3. Baseline Y for 'T' top should match
4. Snow height distribution after 30s should be similar
5. Average stack height should be ~6-7 pixels on both

### Debug Logging

Both platforms log similar information:
```
iOS: "❄️ Setting snow effect targets: 15 total bounds"
Android: "🎯 SnowEffect received 15 target bounds"

iOS: "📊 Particles - Falling: 47, Sliding: 0, Total: 47"
Android: "📊 Particles - Falling: 47, Sliding: 0, Total: 47"
```

Use these logs to verify identical behavior across platforms.
