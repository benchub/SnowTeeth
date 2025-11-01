# Coordinate Transformation Fix

## Current Situation
- p.y=0 is at **middle** of screen
- Flame at p.y=0 to 0.2 appears in **lower half** ✓ (correct relative position)
- **Goal**: p.y=0 at **bottom** of screen

## Ray Sampling Math

UV coordinate at screen positions:
```
uv.y = -1  (top screen)
uv.y = 0   (middle screen)
uv.y = +1  (bottom screen)
```

Ray direction from center column:
```
dir = normalize(vec3(0, uv.y, -1))
```

At march distance z, p.y sampled:
```
p.y = z * (uv.y / sqrt(uv.y^2 + 1))
```

Current behavior (no shift):
```
Top screen (uv.y=-1):    p.y < 0 (negative)
Middle screen (uv.y=0):  p.y = 0
Bottom screen (uv.y=+1): p.y > 0 (positive)
```

## What We Need

We want:
```
Top screen:    p.y = 2
Middle screen: p.y = 1
Bottom screen: p.y = 0
```

This requires: **p.y_new = 1 - p.y_old**

Or equivalently, flip the ray by inverting uv.y BEFORE creating ray direction:
```
uv.y = -uv.y  // This is already done
uv.y = -uv.y  // Do it again to undo, or just remove the first flip
```

Wait, that's not quite right. Let me recalculate...

Actually, we need p.y to INCREASE going DOWN the screen (opposite of current).

Current: bottom screen has positive p.y, top has negative
Want: bottom screen has p.y=0, top has p.y=2

Solution: **p.y = 1 - p.y** after sampling

Or at the ray level: don't flip uv.y at all, or flip it twice.

Let me trace through exactly:

```glsl
// Current code
vec2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
uv.y = -uv.y;  // This flips so bottom is +1, top is -1
```

For bottom pixel: uv.y = +1, ray goes UP in world space (p.y increases)
For top pixel: uv.y = -1, ray goes DOWN in world space (p.y decreases)

To make bottom=0 and top=2, we need to:
1. Keep the flip (bottom still needs to sample lower p.y than top)
2. But shift: p.y_new = (1 - uv.y)

At bottom (uv.y=+1): p.y_base = 0
At middle (uv.y=0): p.y_base = 1
At top (uv.y=-1): p.y_base = 2

Then as rays march: p.y = p.y_base + z * ray.y

Actually simpler: just shift p.y by 1 AFTER creating the ray but considering the sign.

Let me think more carefully with actual numbers at z=0:

Bottom center: uv=(0,1), direction=(0, 0.707, -0.707), at z=0: p.y=0
We want: p.y=0 at bottom ✓

Top center: uv=(0,-1), direction=(0, -0.707, -0.707), at z=0: p.y=0
We want: p.y=2 at top ✗ (off by 2)

So we need: p.y_shifted = p.y_original + (something that depends on uv.y)

The base p.y before marching is always 0. We need to offset it based on screen position.

Actually, the simplest fix: Add 1-uv.y to p.y after the ray computation:

```glsl
vec3 p = z * normalize(vec3(uv, -1.0));
p.y += 1.0 - uv.y;  // bottom(uv.y=1): +0, top(uv.y=-1): +2
```

Wait, let me verify with actual z values:

Bottom center at z=0.5:
- p.y = 0.5 * 0.707 = 0.354
- With shift: 0.354 + (1-1) = 0.354

Top center at z=0.5:
- p.y = 0.5 * (-0.707) = -0.354
- With shift: -0.354 + (1-(-1)) = -0.354 + 2 = 1.646

That gives us bottom sampling ~0.35 and top sampling ~1.65 at z=0.5.

But we want bottom at 0 and top at 2. Hmm, the base offset isn't quite right.

Let me try: p.y += 1 - uv.y * z_scaling

Actually, I think the issue is that we're adding a constant when we should be setting a base.

New approach: Set p.y base before marching:
```glsl
vec3 p = z * normalize(vec3(uv, -1.0));
float base_y = 1.0 - uv.y;  // bottom: 0, middle: 1, top: 2
p.y += base_y;
```

Let me verify:
Bottom (uv.y=1) at z=0.5: p.y = 0.354 + 0 = 0.354
Top (uv.y=-1) at z=0.5: p.y = -0.354 + 2 = 1.646

Still not quite at 0 and 2, but closer. The issue is the rays are also moving in Y as they march.

I think the real fix is simpler: just invert the Y direction of rays by NOT flipping uv.y, then shift by 1.

Let me compute what happens if we DON'T flip uv.y:
```glsl
vec2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
// Don't flip: uv.y as-is
// Bottom: uv.y = -1
// Top: uv.y = +1
```

Then rays:
Bottom (uv.y=-1): direction = (0, -0.707, -0.707), marches DOWN
Top (uv.y=+1): direction = (0, 0.707, -0.707), marches UP

Then add: p.y += 1.0

Bottom at z=0: p.y = 0 + 1 = 1
Top at z=0: p.y = 0 + 1 = 1

Bottom at z=0.5: p.y = -0.354 + 1 = 0.646
Top at z=0.5: p.y = 0.354 + 1 = 1.354

Hmm, that makes bottom HIGHER than top, which is backwards.

OK one more try. The CURRENT behavior is:
- uv.y flipped
- Bottom rays march upward in Y (toward positive p.y)
- Top rays march downward in Y (toward negative p.y)
- p.y=0 is at middle

To shift p.y=0 to bottom, I need: **p.y += 1.0** (shift entire range up by 1)

Then:
- Bottom rays start at p.y ≈ 0 and march upward
- Top rays start at p.y ≈ 2 and march downward
- They all sample the 0-2 range

Let me verify with numbers:
Bottom center at z=0: p.y = 0 + 1 = 1 (not 0!) ✗
Bottom center at z=sqrt(2): p.y = 1.0 + 1 = 2.0 ✗

That's not right either. The issue is that z=0 always gives p.y=0 regardless of screen position.

OH! I see the issue. The ray starts at the camera, which is at p.y=0. As it marches, it moves in the ray direction. For bottom pixels, the ray goes UP (positive Y), for top pixels it goes DOWN (negative Y).

What we want is the CAMERA to be below the flame, looking up. So camera should be at p.y = -1, and the visible range should be -1 to +1 (centered at 0).

Then to make bottom=0 and top=2, we shift by +1:
- Camera at p.y = 0 (was -1, shifted by +1)
- Visible range: 0 to 2

So: **p.y += 1.0** is the right answer!

But then why does the user see p.y=0 in the middle?

OH WAIT. The grid is showing where rays SAMPLE p.y values at z≈0.5, not where they START.

Let me recalculate the grid for p.y += 1.0 shift:

With shift, at z=0.5:
Bottom center: p.y = 0.354 + 1.0 = 1.354
Middle center: p.y = 0 + 1.0 = 1.0
Top center: p.y = -0.354 + 1.0 = 0.646

So middle samples p.y=1.0 at z=0.5.

But the user is saying they see p.y=0 in the middle. That means... we DON'T have p.y += 1.0 applied!

Let me check the current code...
