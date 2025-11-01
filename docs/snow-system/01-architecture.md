# System Architecture

## Overview

The snow accumulation system is built around a height-map optimization inspired by xsnow, where each surface tracks snow depth at discrete X coordinates instead of maintaining individual stuck particle positions.

## Core Components

### 1. SnowEffect (Coordinator)

**iOS**: `/iOS/SnowTeeth/Effects/SnowEffect.swift`
**Android**: `/android/app/src/main/java/com/snowteeth/app/effects/SnowEffect.kt`

Main coordinator that:
- Manages falling snowflake particles
- Maintains collision targets (letters, buttons, ground)
- Creates and manages FallenSnow instances per surface
- Handles gravity and wind simulation
- Spawns new particles and removes off-screen ones

### 2. FallenSnow (Height-Map)

**iOS**: Nested class in `SnowEffect.swift` (lines 313-432)
**Android**: `/android/app/src/main/java/com/snowteeth/app/effects/FallenSnow.kt`

Per-surface height-map that:
- Tracks snow depth at each integer X coordinate
- Stores baseline Y (surface contour) at each X coordinate
- Performs path sampling to determine surface shape
- Handles probabilistic snow addition
- Implements random erosion for natural dynamics

**Data Structure**:
```swift
private var heights: [CGFloat]      // Current snow depth at each X
private var baselineYs: [CGFloat]   // Surface Y position at each X
private let offsetX: CGFloat        // Global X offset of this surface
```

### 3. Snowflake (Particle)

**iOS**: `SnowEffect.swift` (lines 28-100)
**Android**: `/android/app/src/main/java/com/snowteeth/app/Snowflake.kt`

Individual particle with:
- Position (x, y)
- Velocity (vx, vy)
- Size (radius)
- Opacity
- State (Falling, Sliding, Stuck, Gone)

### 4. LetterBoundsCalculator

**iOS**: `/iOS/SnowTeeth/Effects/LetterBoundsCalculator.swift`
**Android**: `/android/app/src/main/java/com/snowteeth/app/effects/LetterBoundsCalculator.kt`

Calculates individual letter bounds and paths:
- Uses CoreText (iOS) or Paint.getTextPath (Android)
- Returns tight bounding boxes for each character
- Provides CGPath/Path for contour sampling
- Transforms paths to global screen coordinates

### 5. SnowEffectView (Renderer)

**iOS**: `/iOS/SnowTeeth/Effects/SnowEffectView.swift`
**Android**: `/android/app/src/main/java/com/snowteeth/app/effects/SnowParticleView.kt`

Renders:
- Falling/sliding snowflake particles
- Height-map visualizations (vertical stacks)

## Data Flow

```
1. ContentView captures UI element bounds
   ↓
2. LetterBoundsCalculator generates paths
   ↓
3. SnowEffect receives collision targets
   ↓
4. FallenSnow samples paths to build baseline arrays
   ↓
5. Update loop:
   - Spawn new particles
   - Update particle positions
   - Check collisions against height-maps
   - Add snow to height-maps (probabilistic)
   - Erode random stacks
   - Remove off-screen particles
   ↓
6. SnowEffectView renders particles and height-maps
```

## Coordinate Systems

### iOS
- **Global coordinates**: Screen-space with origin at top-left
- **CoreText coordinates**: Origin at baseline, Y+ goes up
- **SwiftUI coordinates**: Named coordinate space "snowCoordinateSpace"
- **Transformation**: CoreText paths transformed to global via CGAffineTransform

### Android
- **Global coordinates**: Screen-space with origin at top-left
- **Canvas coordinates**: Same as global
- **Path coordinates**: Generated in global space via getTextPath()

## Performance Characteristics

- **Collision detection**: O(1) per particle (height-map lookup)
- **Height-map sampling**: O(W × H/s) where W=width, H=height, s=step size (0.1px)
  - Performed once at initialization per surface
- **Update loop**: O(N) where N=number of active particles
- **Rendering**: O(N + M) where M=number of non-zero height-map columns

## Memory Usage

Per surface:
- `heights`: Float array of width W
- `baselineYs`: Float array of width W
- Total: ~8 bytes × W × 2 per surface

Typical app with "SnowTeeth" (9 letters) + 5 buttons + ground = 15 surfaces
Average width: 50 pixels per surface
Total: ~8 × 50 × 2 × 15 = ~12KB for all height-maps
