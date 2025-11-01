# Contour-Following Height-Map Implementation

## Concept

Instead of using a flat top surface for each letter, the system samples the actual glyph path to determine the exact Y position of the surface at each X coordinate. This allows snow to follow curves like the arch of 'h' or the curves of 'S'.

## Data Structure

Each `FallenSnow` instance maintains two parallel arrays:

```swift
private var heights: [CGFloat]      // Snow depth at each X (0 to maxHeight)
private var baselineYs: [CGFloat]   // Surface Y position at each X
```

**Key insight**: The baseline follows the surface contour, not a flat line.

## Initialization Process

### 1. X Coordinate Sampling

**iOS** (`SnowEffect.swift:93-97`):
```swift
let startX = Int(ceil(target.bounds.minX))
let endX = Int(floor(target.bounds.maxX))
let width = max(0, endX - startX + 1)
let offsetX = CGFloat(startX)
```

**Android** (`SnowEffect.kt:80-84`):
```kotlin
val startX = kotlin.math.ceil(target.bounds.left).toInt()
val endX = kotlin.math.floor(target.bounds.right).toInt()
val width = maxOf(0, endX - startX + 1)
val offsetX = startX.toFloat()
```

**Important**: Use `ceil(minX)` to `floor(maxX)` to only sample integer pixels actually inside the bounds. This prevents gaps or overlaps between adjacent surfaces.

### 2. Path Sampling per Column

For each X coordinate, perform vertical ray-casting to find the topmost point of the surface:

**iOS** (`SnowEffect.swift:356-370`):
```swift
private func findTopOfPathAt(x: CGFloat, path: CGPath, bounds: CGRect) -> CGFloat {
    if x < bounds.minX || x > bounds.maxX {
        return bounds.maxY + 1000  // Far below screen
    }

    // Use fine sampling (0.1 pixels) to catch thin strokes like the arch of 'h'
    let step: CGFloat = 0.1
    for y in stride(from: bounds.minY, through: bounds.maxY, by: step) {
        if path.contains(CGPoint(x: x, y: y)) {
            return y  // Found the top of the surface
        }
    }
    return bounds.maxY + 1000  // No intersection found
}
```

**Android** (`FallenSnow.kt:59-91`):
```kotlin
private fun findTopOfPathAt(x: Float, path: Path, bounds: RectF): Float {
    if (x < bounds.left || x > bounds.right) {
        return bounds.bottom + 1000f
    }

    // Use fine sampling (0.1 pixels) to catch thin strokes
    val step = 0.1f
    var y = bounds.top

    // Set up region for path testing in global coordinates
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
            return y  // Found the top of the surface
        }
        y += step
    }
    return bounds.bottom + 1000f
}
```

**Critical parameter**: Step size of **0.1 pixels** is required to detect thin strokes like:
- The arch of lowercase 'h'
- The top of lowercase 't'
- Thin serifs or stroke endpoints

Using 0.5 pixels was insufficient and caused snow to fall through the 'h' arch.

### 3. Button Corner Handling

Buttons have no path, only rectangular bounds. To prevent accumulation on visually rounded corners:

**iOS** (`SnowEffect.swift:346-354`):
```swift
// Button corner detection
let cornerRadius: CGFloat = 15.0
if x < bounds.minX + cornerRadius || x > bounds.maxX - cornerRadius {
    self.baselineYs[i] = bounds.maxY + 1000  // Set baseline far below
} else {
    self.baselineYs[i] = bounds.minY  // Flat middle section
}
```

**Android** (`FallenSnow.kt:42-55`):
```kotlin
val cornerRadius = 15f * 3  // Convert dp to pixels (roughly)
val leftEdge = bounds.left + cornerRadius
val rightEdge = bounds.right - cornerRadius

if (x < leftEdge || x > rightEdge) {
    // In corner area - set baseline very low so snow doesn't accumulate
    bounds.bottom + 1000f
} else {
    // Flat middle section
    bounds.top
}
```

**Note**: Android uses 45px (15dp × 3 for xhdpi) to match the visual corner radius.

## Collision Detection

Once height-maps are initialized, collision is a simple lookup:

**iOS** (`SnowEffect.swift:423-426`):
```swift
func collides(x: CGFloat, y: CGFloat) -> Bool {
    guard x >= offsetX && x < offsetX + CGFloat(width) else { return false }
    let baseline = baselineY(at: x)
    let snowTop = topY(at: x)
    // Allow a small buffer (3 pixels) below the surface for collision detection
    return y >= snowTop && y <= baseline + 3
}
```

**Android** (`FallenSnow.kt:167-177`):
```kotlin
fun collides(x: Float, y: Float): Boolean {
    // Check if x is within this surface's bounds
    if (x < offsetX || x >= offsetX + width) return false

    val baseline = baselineY(x)
    val snowTop = topY(x)

    // Only collide if the snowflake is close to this surface's baseline at this X
    // Allow a small buffer (3 pixels) below the surface for collision detection
    return y >= snowTop && y <= baseline + 3f
}
```

**Important**: The collision check uses the **center** of the snowflake, not the bottom edge, to avoid "floating" appearance.

## Visualization

The height-map can be visualized as vertical white bars:

**iOS** (`SnowEffectView.swift:53-68`):
```swift
// Draw fallen snow height-maps
for (_, surfaceMap) in snowEffect.surfaceSnowMaps {
    for (x, height, baseline) in surfaceMap.getHeights() {
        if height > 0 {
            let rect = CGRect(
                x: x,
                y: baseline - height,
                width: 1,
                height: height
            )
            context.fill(Rectangle().path(in: rect), with: .color(.white))
        }
    }
}
```

This renders each column as a 1-pixel-wide vertical bar from the baseline up to the snow height.

## Performance

- **Initialization**: O(W × H / step) per surface
  - W = width in pixels (typically 20-100)
  - H = height in pixels (typically 30-60)
  - step = 0.1 pixels
  - Example: 50 × 40 / 0.1 = 20,000 iterations per surface
  - Takes ~0.1-0.5ms per surface on modern devices

- **Collision detection**: O(1) per particle
  - Just array lookup: `heights[ix]` and `baselineYs[ix]`
  - Typically ~0.001ms per check

## Edge Cases

1. **X outside bounds**: Return baseline far below screen (bounds.maxY + 1000)
2. **No path intersection found**: Return baseline far below screen
3. **Empty path**: Treated as button (no glyph path)
4. **Zero width**: Handled by `max(0, endX - startX + 1)`
