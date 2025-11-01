# Santa Animation Algorithm

## Overview
This algorithm controls the Santa flying animation that appears periodically across the screen, creating a festive visual element.

## Core Mechanics

### Timing
- **Flight Interval**: Santa flies across the screen every 42 seconds
- **Flight Duration**: 8 seconds to cross from one edge to the other
- **Initial Delay**: 2 seconds after app launch before first flight

### Direction Randomization (New)
Each flight randomly selects a direction:
- **Left-to-Right**: Starts at x = -150 (off-screen left), ends at x = screenWidth + 150 (off-screen right)
- **Right-to-Left**: Starts at x = screenWidth + 150 (off-screen right), ends at x = -150 (off-screen left)
- Direction is randomized using a boolean random value on each `startFlying()` call

### Sprite Animation
- **Frame Count**: 4 frames (MediumSantaRudolf1-4)
- **Frame Rate**: 10 FPS (updates every 0.1 seconds)
- **Cycling**: Frames cycle continuously while flying: `currentFrame = (currentFrame + 1) % frameCount`

### Sprite Flipping
When flying right-to-left, the sprite is horizontally flipped:
- **iOS**: Uses `.scaleEffect(x: -1, y: 1)` SwiftUI modifier
- **Android**: Uses `Matrix.preScale(-1f, 1f)` to flip the bitmap before drawing

## Platform-Specific Implementation

### iOS (SwiftUI)
```swift
@State private var flyingLeftToRight: Bool = true

// In body:
.scaleEffect(x: flyingLeftToRight ? 1 : -1, y: 1)

// In startFlying():
flyingLeftToRight = Bool.random()
let (startX, targetX) = flyingLeftToRight
    ? (-150, screenWidth + 150)
    : (screenWidth + 150, -150)
santaPosition = startX

withAnimation(.linear(duration: 8.0)) {
    santaPosition = targetX
}
```

### Android (Kotlin)
```kotlin
private var flyingLeftToRight: Boolean = true

// In onDraw():
if (!flyingLeftToRight) {
    val matrix = android.graphics.Matrix()
    matrix.preScale(-1f, 1f)
    scaledBitmap = Bitmap.createBitmap(
        scaledBitmap, 0, 0,
        scaledBitmap.width, scaledBitmap.height,
        matrix, false
    )
}

// In startFlying():
flyingLeftToRight = kotlin.random.Random.nextBoolean()
val (startX, targetX) = if (flyingLeftToRight) {
    Pair(-150f, width + 150f)
} else {
    Pair(width + 150f, -150f)
}
santaX = startX

// Position animation runnable updates santaX over 8 seconds
```

## Offscreen Detection
Detection logic adapts to flight direction:
```kotlin
val isOffScreen = if (flyingLeftToRight) {
    santaX >= width + 150f
} else {
    santaX <= -150f
}
```

## Visual Effect
The direction randomization creates:
- **Variety**: Each flight feels unique
- **Natural**: Santa can approach from either direction
- **Surprise**: Users don't know which way he'll fly next
- **Polish**: Proper sprite flipping maintains correct orientation

## Implementation Notes

### Performance Considerations
- Bitmap flipping creates a new bitmap on each frame (Android)
- Old bitmaps are properly recycled to prevent memory leaks
- SwiftUI's scaleEffect is hardware-accelerated and very efficient

### Edge Cases
- If screen width is 0, flight doesn't start (prevents division by zero)
- If already flying, new flight request is ignored
- Sprite flipping preserves aspect ratio and size

## Testing Considerations
- Verify Santa appears from both left and right edges randomly
- Confirm sprite is correctly oriented in both directions
- Check that offscreen detection works for both directions
- Validate that bitmap recycling prevents memory leaks (Android)
- Ensure animation is smooth in both directions
