# Coordinate System Analysis

## UV Coordinate Mapping

```glsl
vec2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
uv.y = -uv.y;
```

For a screen with height H:
- Bottom pixel (fragCoord.y = 0):
  - (0 * 2.0 - H) / H = -H / H = -1.0
  - After flip: uv.y = 1.0

- Top pixel (fragCoord.y = H):
  - (H * 2.0 - H) / H = H / H = 1.0
  - After flip: uv.y = -1.0

**Result: Bottom of screen has uv.y = 1.0, Top has uv.y = -1.0**

## Ray Direction

```glsl
float3 p = z * normalize(float3(uv, -1.0));
```

Ray direction = normalize(vec3(uv.x, uv.y, -1.0))

For bottom center pixel (uv = (0, 1, -1)):
- Direction ≈ (0, 0.707, -0.707)
- As z increases: p.y increases (ray goes UP)

For top center pixel (uv = (0, -1, -1)):
- Direction ≈ (0, -0.707, -0.707)
- As z increases: p.y decreases (ray goes DOWN)

## Current Problem

With height = 0.1:
- flameTop = 0.0 + 0.1 * 2.0 = 0.2

Expected: Flame only visible where p.y <= 0.2

Reality: User sees flame reaching screen positions labeled p.y = 1.0

## Sampling at Different Z Values

For bottom center pixel:
- z = 0: p.y = 0
- z = 0.707: p.y ≈ 0.5
- z = 1.414: p.y ≈ 1.0
- z = 2.828: p.y ≈ 2.0

The raymarch samples p.y from 0 to ~5 over 50 iterations.

## The Issue

When pYOriginal = 1.0 (z ≈ 1.414):
- This is > flameTop (0.2)
- Code goes to shrink branch
- targetRadius should shrink to ~0.001
- Distance should be large
- Should NOT accumulate color

**But flame is still visible at p.y = 1.0!**

## Possible Causes

1. Turbulence is pushing samples back into valid range
2. Fade isn't strong enough
3. Color accumulated at p.y < 0.2 is "bleeding" visually upward
4. heightFade isn't cutting off properly
5. The grid overlay mapping is wrong

## Test Case

With height=0.1, turbulence=1.0:
- Expected visible range: p.y 0.0 to 0.2 (plus ~0.3 fade) = 0.0 to 0.5 max
- Actual visible range: p.y 0.0 to 1.0 (reported by user)
- Delta: 0.5 too high!

This suggests the constraint isn't working at all, or turbulence is overriding it by ~0.5 units.
