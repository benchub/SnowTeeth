# Fire Shader Algorithm Explained

This document provides a technical breakdown of how the 3D fire shader works.

## Overview

The shader uses **volumetric raymarching** to render a 3D fire effect. Instead of rendering a surface, it samples 3D space along rays from the camera, accumulating color and density to create the appearance of volumetric fire.

## Core Algorithm

### 1. Ray Setup

```glsl
vec3 p = z * normalize(vec3(I + I, 0) - vec3(iResolution.xy, iResolution.y));
```

- `I` is the current pixel coordinate
- Creates a ray direction from camera through the pixel
- `z` is the current distance along the ray
- The ray is normalized to maintain consistent step sizes

### 2. Vertical Animation

```glsl
p.z += 5.0 + cos(t) * u_height;
```

- Offsets the ray sample point in Z
- `5.0` is the base distance
- `cos(t)` creates gentle vertical oscillation
- `u_height` controls the amplitude of the oscillation
- This makes the fire appear to pulse and breathe

### 3. Twist Rotation

```glsl
mat2 rotMat = mat2(cos(p.y * 0.5 + vec4(0, 33, 11, 0)));
p.xz *= rotMat / max(p.y * 0.1 + 1.0, 0.1);
```

- Creates a rotation matrix based on the Y coordinate
- Rotates the XZ plane (horizontal rotation)
- The rotation angle increases with height (`p.y * 0.5`)
- Division by `max(p.y * 0.1 + 1.0, 0.1)` creates a twisting effect
- Higher parts of the fire twist more, creating realistic flame curling

### 4. Multi-Octave Turbulence

```glsl
float freq = 2.0;
for(int turbLoop = 0; turbLoop < 8; turbLoop++) {
    p += cos((p.yzx - vec3(t / 0.1, t, freq)) * freq * u_turbulence) / freq;
    freq = freq / 0.6;
}
```

This is the heart of the fire's organic appearance:

- **8 iterations** of turbulence at different frequencies
- Each iteration adds noise at a specific scale
- `freq` starts at 2.0 and increases each iteration
- `freq / 0.6` means each octave has ~1.67x the frequency
- The cosine function creates smooth, periodic distortion
- `p.yzx` is a swizzle (reordering Y→X, Z→Y, X→Z) that adds variation
- Division by `freq` ensures higher frequencies have smaller amplitude
- Time offsets (`t / 0.1`, `t`) create animation at different speeds

**Why this works:**
- Low frequencies (early iterations): Large-scale flame motion
- High frequencies (later iterations): Fine details and turbulence
- This mimics natural turbulent flow in real fire

### 5. Distance Field (Hollow Cone)

```glsl
float dist = 0.01 + abs(length(p.xz) + p.y * 0.3 - 0.5) / 7.0;
```

Defines the shape of the fire:

- `length(p.xz)` is the distance from the central axis (cylinder)
- `p.y * 0.3` makes the cylinder taper with height
- `- 0.5` offsets the surface
- `abs(...)` creates a hollow shape (fire is brightest at edges)
- `/ 7.0` scales the distance field
- `0.01 +` prevents division by zero later

**Hollow cone geometry:**
```
     *   *      <- Top: narrow, spread out
    *  *  *
   *   *   *    <- Middle: widening
  *    *    *
 *     *     *  <- Base: wide hollow cone
```

### 6. Ray Advancement

```glsl
z += dist;
d = dist;
```

- Move along the ray by the distance to the nearest surface
- This is **sphere tracing** / **ray marching**
- Larger steps when far from fire, smaller when close
- Ensures we don't miss details while maintaining performance

### 7. Color Accumulation

```glsl
vec4 color = (sin(z / 3.0 + vec4(7, 2, 3, 0) * u_colorShift) + 1.1) / d;
O += color * u_intensity;
```

Creates the fire colors:

- `z / 3.0` varies color based on distance traveled
- `vec4(7, 2, 3, 0)` offsets each channel differently:
  - Red channel: offset by 7 → appears sooner (innermost)
  - Green channel: offset by 2 → middle layer
  - Blue channel: offset by 3 → outer layer
  - Alpha channel: offset by 0 → uniform
- `sin(...)` oscillates between -1 and 1
- `+ 1.1` shifts range to [0.1, 2.1] (mostly positive, warm colors)
- `/ d` makes closer areas brighter (inverse square law)
- `* u_intensity` scales overall brightness

**Color gradient:**
```
Core (z small):  Red dominant  → Red/Orange
Middle:          Green increases → Orange/Yellow
Outer:           Balanced       → Yellow/White
Far:             Blue increases → Cooler tones
```

### 8. Tone Mapping

```glsl
vec4 tanhApprox(vec4 x) {
    vec4 x2 = x * x;
    return x * (3.0 + x2) / (3.0 + 3.0 * x2);
}

O = tanhApprox(O / 1000.0);
```

- Accumulated color can exceed [0, 1] range
- Division by 1000 scales down accumulated values
- Tanh approximation compresses to [0, 1] smoothly
- Preserves bright areas without harsh clipping
- Creates natural HDR-like appearance

## Parameter Effects

### Speed (0.5 - 2.0)
- Multiplies time value
- Higher = faster animation
- Affects both turbulence movement and vertical oscillation

### Intensity (0.5 - 3.0)
- Multiplies color accumulation
- Higher = brighter, more visible fire
- Too high = oversaturated, washed out

### Height (0.5 - 2.0)
- Amplitude of vertical oscillation
- Higher = taller flames
- Creates more dramatic movement

### Turbulence (0.5 - 2.0)
- Multiplies the turbulence displacement
- Higher = more chaotic, detailed fire
- Too high = noisy, less coherent

### Color Shift (0.5 - 2.0)
- Shifts the phase of color sine waves
- Lower = cooler colors (more blue)
- Higher = hotter colors (more white/yellow)

## Performance Characteristics

- **50 raymarching iterations**: Fixed cost per pixel
- **8 turbulence iterations**: Nested, 400 iterations per pixel total
- **Cosine calculations**: ~450 per pixel (in turbulence loops)
- **No texture lookups**: Pure mathematical computation
- **No branching**: Fully coherent execution

**Expected performance:**
- Mobile (iPhone 12+): ~60 FPS at 1080p
- Desktop (integrated GPU): ~60 FPS at 1440p
- Desktop (dedicated GPU): ~60 FPS at 4K

## Optimization Opportunities

If you need better performance:

1. **Reduce raymarch iterations**: Change `50.0` to `30.0` or `40.0`
2. **Reduce turbulence octaves**: Change `8` to `6` or `5`
3. **Use lower resolution**: Render at half-resolution, upscale
4. **Adaptive quality**: Reduce iterations on mobile devices
5. **Level of detail**: Use simpler version when fire is small on screen

## Extension Ideas

### Multiple Fires
Create an array of fire positions and raymarch to each:

```glsl
for (int fireIndex = 0; fireIndex < numFires; fireIndex++) {
    vec3 firePos = firePositions[fireIndex];
    // Run raymarch with p offset by firePos
}
```

### Wind Effect
Add a directional offset to the turbulence:

```glsl
vec3 windOffset = vec3(sin(t) * windStrength, 0, cos(t) * windStrength);
p += windOffset;
```

### Smoke Transition
Use higher octaves of turbulence with different colors for smoke at the top:

```glsl
if (p.y > smokeHeight) {
    // Use gray colors and different turbulence
}
```

### Interactivity
Pass touch/mouse position as uniform and bend the fire toward it:

```glsl
vec2 forceDir = touchPos - p.xz;
p.xz += forceDir * forcStrength / length(forceDir);
```

## Mathematical Foundations

The shader combines several mathematical concepts:

1. **Signed Distance Fields (SDF)**: The hollow cone distance function
2. **Fractional Brownian Motion (fBM)**: Multi-octave turbulence
3. **Ray Marching**: Iterative ray-surface intersection
4. **Volume Rendering**: Accumulating semi-transparent samples
5. **Procedural Noise**: Cosine-based turbulence
6. **Tone Mapping**: HDR to LDR conversion

## References

- Original concept: [shadcn.io/shaders/fire-3d-shaders](https://www.shadcn.io/shaders/fire-3d-shaders)
- Ray marching: Íñigo Quílez's articles on distance functions
- Volume rendering: "Real-Time Rendering" book, Chapter 14
- Turbulence: Ken Perlin's noise function research
