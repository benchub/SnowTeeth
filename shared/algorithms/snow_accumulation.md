# Snow Accumulation Algorithm

## Overview
This algorithm controls how snow accumulates on surfaces, creating natural-looking piles with realistic spreading behavior.

## Core Mechanics

### Height-Based Accumulation
Snow accumulates in vertical columns, where each X coordinate has:
- **Height**: Current snow stack height at that position
- **Baseline Y**: The surface Y coordinate where snow lands (follows the surface contour)

### Surface Types
Different surfaces have different accumulation limits:

**Regular Surfaces** (letters, buttons):
- Comfortable Height: 5 pixels
- Maximum Height: 15 pixels

**Ground Surface** (bottom of screen):
- Comfortable Height: 15 pixels (3x regular)
- Maximum Height: 45 pixels (3x regular)
- Allows deeper accumulation for more visible snow piling at the bottom

### Probabilistic Stacking
Snow stacking uses a tiered probability system:

1. **Comfortable Height (0-5px regular, 0-15px ground)**: Always allow stacking
   - Probability = 100%
   - Creates a stable base layer

2. **Excess Height (5-15px regular, 15-45px ground)**: Probabilistic stacking
   - Probability = `(1 - (excess / maxExcess))^3`
   - Cubic falloff creates natural variation
   - Example: At halfway point, probability = 12.5%

3. **Maximum Height (15px regular, 45px ground)**: Hard cap
   - Probability = 0%
   - Prevents infinite accumulation

### Neighbor Spreading (New)
When snow cannot stack at the target column (rejected by probability or at max height), it attempts to spread to neighboring columns:

1. **Check Rejection**: If `addSnow()` returns `false`
2. **Find Lower Neighbors**: Check left (ix-1) and right (ix+1) columns
   - Only consider neighbors with `height < currentHeight`
   - This ensures snow flows "downhill" to lower areas
3. **Random Selection**: Randomly pick one qualifying neighbor
4. **Attempt Addition**: Try to add 1 pixel to the selected neighbor
   - Subject to the same probabilistic rules
   - May also be rejected if neighbor is near max height

This creates natural spreading behavior where snow:
- Fills in gaps between high points
- Creates more realistic, rounded accumulation
- Avoids perfectly vertical stacks
- Simulates natural snow drift

## Implementation Notes

### Coordinate Handling
- All X coordinates are converted to array indices: `ix = x - offsetX`
- Bounds checking is critical: `ix >= 0 && ix < width`
- Neighbors must also be bounds-checked before access

### Performance Considerations
- Neighbor checks add minimal overhead (2 array accesses)
- Random selection is O(1) for 1-2 candidates
- No recursive spreading (single-level only)

### Edge Cases
- **No valid neighbors**: Snow is simply discarded (natural behavior)
- **Both neighbors lower**: Randomly pick one
- **One neighbor lower**: Use that one
- **Edge columns**: Only check the single available neighbor

## Pseudocode

```
function addSnow(x, amount, depth = 0):
    ix = convertToIndex(x)
    if not inBounds(ix):
        return false

    currentHeight = heights[ix]

    // Hard cap at maxHeight (15px regular, 45px ground)
    if currentHeight >= maxHeight:
        return trySpreadToNeighbors(ix, currentHeight, depth)

    // Check if current stack is 2x higher than any neighbor (balancing)
    if depth == 0:
        neighborIx = findBalancedNeighbor(ix, currentHeight)
        if neighborIx != null:
            return addSnow(neighborIx, amount, depth + 1)

    // Always allow stacking below comfortable height (5px regular, 15px ground)
    if currentHeight < comfortableHeight:
        heights[ix] = min(heights[ix] + amount, maxHeight)
        return true

    // Above comfortable height: probabilistic stacking
    excessHeight = currentHeight - comfortableHeight
    maxExcess = maxHeight - comfortableHeight  // 10 pixels for both types
    probability = (1.0 - (excessHeight / maxExcess))^3  // Cubic falloff

    if random() < probability:
        heights[ix] = min(heights[ix] + amount, maxHeight)
        return true

    // Rejected by probability - try spreading to neighbors
    return trySpreadToNeighbors(ix, currentHeight, depth)

function trySpreadToNeighbors(ix, currentHeight, depth):
    lowerNeighbors = []

    // Check left neighbor
    if ix > 0 and heights[ix-1] < currentHeight:
        lowerNeighbors.append(ix-1)

    // Check right neighbor
    if ix < width-1 and heights[ix+1] < currentHeight:
        lowerNeighbors.append(ix+1)

    // Spread to a random lower neighbor
    if lowerNeighbors.notEmpty():
        neighborIx = random.choice(lowerNeighbors)
        return addSnow(neighborIx, 1.0, depth + 1)  // Add 1 pixel to neighbor

    return false  // No valid neighbors, snow discarded
```

## Visual Effect
The spreading behavior creates:
- Smoother, more natural-looking snow piles
- Gradual transitions between high and low areas
- Realistic "mounding" effect
- Less uniform, more organic appearance

## Implementation Notes

### Creating FallenSnow Surfaces

**iOS:**
```swift
// Regular surface (letter, button)
FallenSnow(width: width, bounds: bounds, path: path, offsetX: offsetX)

// Ground surface (bottom of screen)
FallenSnow(width: width, bounds: bounds, path: nil, offsetX: offsetX, isGround: true)
```

**Android:**
```kotlin
// Regular surface (letter, button)
FallenSnow(width, bounds, path, offsetX, density)

// Ground surface (bottom of screen)
FallenSnow(width, bounds, null, offsetX, density, isGround = true)
```

The `isGround` parameter determines whether to use 3x accumulation limits.

### Constants
```
Regular surfaces:
  comfortableHeight = 5.0 pixels
  maxHeight = 15.0 pixels

Ground surface:
  comfortableHeight = 15.0 pixels (3x)
  maxHeight = 45.0 pixels (3x)
```

## Testing Considerations
- Verify spreading stops at surface boundaries
- Confirm no infinite recursion (depth parameter prevents it)
- Check edge behavior at surface start/end
- Validate that snow prefers lower neighbors
- Test that ground accumulates 3x more than other surfaces
