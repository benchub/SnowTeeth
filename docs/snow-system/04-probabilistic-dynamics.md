# Probabilistic Snow Dynamics

## Overview

Instead of a hard cap on snow accumulation, the system uses probabilistic stacking combined with random erosion to create natural-looking varied snow heights that evolve over time.

## Stacking Behavior

### Three-Zone Model

1. **Comfortable Height (0-5 pixels)**: Always allowed
2. **Probabilistic Zone (5-15 pixels)**: Increasingly unlikely with cubic falloff
3. **Hard Cap (15 pixels)**: Never exceeded

### Constants

**iOS** (`SnowEffect.swift:317-318`):
```swift
private let comfortableHeight: CGFloat = 5.0
private let maxHeight: CGFloat = 15.0
```

**Android** (`FallenSnow.kt:23-24`):
```kotlin
private val comfortableHeight: Float = 5f
private val maxHeight: Float = 15f
```

### Implementation

**iOS** (`SnowEffect.swift:392-419`):
```swift
func addSnow(at x: CGFloat, amount: CGFloat = 1.0) -> Bool {
    let ix = Int(x - offsetX)
    guard ix >= 0 && ix < width else { return false }

    let currentHeight = heights[ix]

    // Hard cap at maxHeight
    if currentHeight >= maxHeight {
        return false
    }

    // Always allow stacking below comfortable height
    if currentHeight < comfortableHeight {
        heights[ix] = min(heights[ix] + amount, maxHeight)
        return true
    }

    // Above comfortable height: probabilistic stacking
    // Exponentially decreasing probability from 5 to 15
    let excessHeight = currentHeight - comfortableHeight
    let maxExcess = maxHeight - comfortableHeight  // 10 pixels
    let probability = pow(1.0 - (excessHeight / maxExcess), 3.0)  // Cubic falloff

    if CGFloat.random(in: 0...1) < probability {
        heights[ix] = min(heights[ix] + amount, maxHeight)
        return true
    }

    return false  // Rejected by probability
}
```

**Android** (`FallenSnow.kt:97-126`):
```kotlin
fun addSnow(x: Float, amount: Float = 1.0f): Boolean {
    val ix = (x - offsetX).toInt()
    if (ix < 0 || ix >= width) return false

    val currentHeight = heights[ix]

    // Hard cap at maxHeight
    if (currentHeight >= maxHeight) {
        return false
    }

    // Always allow stacking below comfortable height
    if (currentHeight < comfortableHeight) {
        heights[ix] = minOf(heights[ix] + amount, maxHeight)
        return true
    }

    // Above comfortable height: probabilistic stacking
    // Exponentially decreasing probability from 5 to 15
    val excessHeight = currentHeight - comfortableHeight
    val maxExcess = maxHeight - comfortableHeight  // 10 pixels
    val probability = (1.0f - (excessHeight / maxExcess)).pow(3.0f)  // Cubic falloff

    if (Random.nextFloat() < probability) {
        heights[ix] = minOf(heights[ix] + amount, maxHeight)
        return true
    }

    return false  // Rejected by probability
}
```

## Probability Curve

The cubic falloff formula creates this behavior:

| Current Height | Excess | Probability | Description |
|---------------|--------|-------------|-------------|
| 0-5 px | 0 | 100% | Always allowed |
| 6 px | 1 | ~73% | Very likely |
| 7 px | 2 | ~51% | Moderate |
| 8 px | 3 | ~34% | Somewhat unlikely |
| 10 px | 5 | ~13% | Unlikely |
| 12 px | 7 | ~3% | Very unlikely |
| 14 px | 9 | ~0.1% | Extremely unlikely |
| 15 px | 10 | 0% | Hard cap |

### Mathematical Derivation

```
excessHeight = currentHeight - comfortableHeight
maxExcess = maxHeight - comfortableHeight = 15 - 5 = 10

probability = (1 - excessHeight/maxExcess)³

Examples:
  height=5:  excess=0,  p = (1 - 0/10)³ = 1.0³ = 100%
  height=7:  excess=2,  p = (1 - 2/10)³ = 0.8³ = 51.2%
  height=10: excess=5,  p = (1 - 5/10)³ = 0.5³ = 12.5%
  height=12: excess=7,  p = (1 - 7/10)³ = 0.3³ = 2.7%
  height=14: excess=9,  p = (1 - 9/10)³ = 0.1³ = 0.1%
  height=15: excess=10, p = (1 - 10/10)³ = 0.0³ = 0%
```

### Why Cubic?

- **Linear falloff** (power=1): Too gradual, many tall stacks
- **Quadratic falloff** (power=2): Still allows too many tall stacks
- **Cubic falloff** (power=3): Aggressive reduction, most stacks stay 5-8 pixels ✅
- **Quartic falloff** (power=4): Too aggressive, rarely exceeds 7 pixels

The cubic curve provides natural-looking variation while keeping most snow at comfortable heights.

## Random Erosion

Every time a snowflake collides and is absorbed into a height-map, a different random column loses 1 pixel of snow. This creates dynamic "melting" behavior.

### Implementation

**iOS** (`SnowEffect.swift:421-427`):
```swift
func erodeRandom() {
    let snowyColumns = heights.indices.filter { heights[$0] > 0 }
    guard !snowyColumns.isEmpty else { return }

    let randomIndex = snowyColumns.randomElement()!
    heights[randomIndex] = max(0, heights[randomIndex] - 1.0)
}
```

**Android** (`FallenSnow.kt:131-138`):
```kotlin
fun erodeRandom() {
    // Find all columns with snow
    val snowyColumns = heights.indices.filter { heights[it] > 0 }
    if (snowyColumns.isEmpty()) return

    // Pick a random snowy column and reduce by 1
    val randomIndex = snowyColumns.random()
    heights[randomIndex] = maxOf(0f, heights[randomIndex] - 1.0f)
}
```

### Where It's Called

**iOS** (`SnowEffect.swift:169-177`):
```swift
if surfaceMap.collides(x: snowflake.position.x, y: snowflake.position.y) {
    // Hit this surface - try to add to height map
    let added = surfaceMap.addSnow(at: snowflake.position.x, amount: snowflake.size)

    // Erode a random stack somewhere else for natural dynamics
    surfaceMap.erodeRandom()

    snowflake.state = .gone
    break
}
```

**Android** (`SnowEffect.kt:173-181`):
```kotlin
if (surfaceMap != null && surfaceMap.collides(snowflake.position.x, snowflake.position.y)) {
    // Hit this surface - try to add to height map
    val added = surfaceMap.addSnow(snowflake.position.x, snowflake.size)

    // Erode a random stack somewhere else for natural dynamics
    surfaceMap.erodeRandom()

    snowflake.state = ParticleState.Gone
    break
}
```

## Emergent Behavior

The combination of probabilistic stacking and random erosion creates several natural effects:

### 1. Dynamic Equilibrium

- High stacks are unlikely to grow (low probability)
- High stacks are likely to erode (more attempts as more snow falls nearby)
- System naturally settles into 5-8 pixel range for most columns

### 2. Varied Terrain

- Not all columns reach the same height
- Some lucky columns reach 10-12 pixels
- Extremely rare columns reach 13-14 pixels
- Creates visually interesting varied landscape

### 3. Continuous Movement

- Even when not accumulating, snow heights change via erosion
- Prevents static, frozen appearance
- Snow appears "alive" and dynamic

### 4. Localized Effects

- Each surface has independent height-map
- Letters can have different snow patterns
- Buttons accumulate differently than text

## Tuning Parameters

### Comfortable Height

**Effect of increasing**:
- More uniform tall stacks
- Less variation in heights
- More "heavy snow" appearance

**Effect of decreasing**:
- More varied terrain
- Earlier probabilistic rejection
- Lighter snow appearance

**Recommended range**: 3-7 pixels

### Max Height

**Effect of increasing**:
- Taller stacks possible (but still rare due to cubic falloff)
- More dramatic height variation
- Longer time to reach equilibrium

**Effect of decreasing**:
- Lower ceiling creates flatter landscape
- Faster equilibrium
- Less dramatic appearance

**Recommended range**: 10-20 pixels

### Falloff Power

**Effect of increasing** (3 → 4):
- Steeper probability curve
- Even fewer tall stacks
- Most snow stays near comfortable height

**Effect of decreasing** (3 → 2):
- Gentler probability curve
- More tall stacks
- Greater height variation

**Recommended range**: 2.5-4.0

## Visual Examples

### Typical Distribution After Equilibrium

For a 100-pixel wide surface after 30 seconds of snow:

```
Height Distribution:
0-5 px:  ~60% of columns (comfortable zone)
6-8 px:  ~30% of columns (probable zone)
9-11 px: ~8% of columns (unlikely zone)
12-14 px: ~2% of columns (very unlikely zone)
15 px:   ~0% of columns (hard cap, extremely rare)
```

This creates a natural-looking varied terrain with most snow at comfortable heights but occasional taller drifts.
