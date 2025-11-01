//
//  FireShader.metal
//  3D Fire Shader for iOS/macOS
//
//  Metal implementation of volumetric fire raymarching shader
//

#include <metal_stdlib>
using namespace metal;

struct FireUniforms {
    float time;
    float speed;
    float intensity;
    float height;
    float turbulence;
    float detail;
    float colorShift;
    float baseWidth;
    float taper;
    float twist;
    float frequency;
    float timeOffset;  // Cumulative time offset to maintain phase continuity
    float2 resolution;
};

// Tanh approximation for tone mapping
float4 tanhApprox(float4 x) {
    float4 x2 = x * x;
    return x * (3.0 + x2) / (3.0 + 3.0 * x2);
}

// Temperature-based color mapping with improved contrast
// Maps temperature value to flame colors: red → orange → yellow → green → blue → white
float3 temperatureToColor(float temp, float variation) {
    // Normalize temperature from [0.5, 2.0] to [0.0, 1.0]
    float t = clamp((temp - 0.5) / 1.5, 0.0, 1.0);

    // Add subtle variation to the temperature to create color strands
    t += variation * 0.05;
    t = clamp(t, 0.0, 1.0);

    // Define color stops with better saturation for volumetric effect
    float3 red = float3(1.0, 0.0, 0.0);
    float3 orange = float3(1.0, 0.4, 0.0);
    float3 yellow = float3(1.0, 0.9, 0.0);
    float3 green = float3(0.0, 0.5, 0.1);  // Darker green for better strand contrast
    float3 cyan = float3(0.0, 0.8, 1.0);
    float3 blue = float3(0.2, 0.4, 1.0);
    float3 white = float3(1.0, 1.0, 1.0);

    // Interpolate through the color sequence with 6 stops
    if (t < 0.166) {
        // Red to Orange
        return mix(red, orange, t / 0.166);
    } else if (t < 0.333) {
        // Orange to Yellow
        return mix(orange, yellow, (t - 0.166) / 0.167);
    } else if (t < 0.5) {
        // Yellow to Green
        return mix(yellow, green, (t - 0.333) / 0.167);
    } else if (t < 0.666) {
        // Green to Cyan
        return mix(green, cyan, (t - 0.5) / 0.166);
    } else if (t < 0.833) {
        // Cyan to Blue
        return mix(cyan, blue, (t - 0.666) / 0.167);
    } else {
        // Blue to White
        return mix(blue, white, (t - 0.833) / 0.167);
    }
}

kernel void fireShader(texture2d<float, access::write> outTexture [[texture(0)]],
                       constant FireUniforms &uniforms [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    float2 fragCoord = float2(gid);
    float2 iResolution = uniforms.resolution;

    // Skip if out of bounds
    if (fragCoord.x >= iResolution.x || fragCoord.y >= iResolution.y) {
        return;
    }

    // Center the coordinates and normalize to [-1, 1] range
    // Flip Y to make flame point upward
    float2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
    uv.y = -uv.y;

    float t = uniforms.timeOffset;  // Use integrated time for phase continuity
    float z = 0.0;
    float4 O = float4(0.0);

    // 50-iteration raymarch loop
    for (float step = 0.0; step < 50.0; step++) {
        // Ray sample computation with animation
        float3 p = z * normalize(float3(uv, -1.0));
        p.z += 5.0 + cos(t) * 0.5;

        // Shift p.y so bottom of screen samples p.y=0, top samples p.y=2
        // After flip: uv.y = +1 at TOP (rays go UP), -1 at BOTTOM (rays go DOWN)
        p.y += uv.y + 1.0;

        // Save original p.y for height/taper calculations (before turbulence)
        float pYOriginal = p.y;

        // Matrix rotation with twist effect
        // Twist parameter controls how much the flame spirals (0 = no twist, higher values = more spiral)
        float angle = p.y * 0.5 * uniforms.twist;
        float cosVal = cos(angle);
        float sinVal = sin(angle);
        float2x2 rotMat = float2x2(cosVal, -sinVal, sinVal, cosVal);

        // Apply fixed scaling factor to prevent corner artifacts with rotation
        float scaleFactor = max(p.y * 0.15 + 1.0, 0.5);
        p.xz = (rotMat * p.xz) / scaleFactor;

        // 8-loop turbulence with frequency scaling
        // turbulence: amplitude (width of displacement)
        // frequency: base wavelength (vertical spacing between kinks)
        // detail: octave scaling factor (how much fine detail is added)
        //   - Lower detail (0.5): octaveFactor ≈ 0.75, less high-freq content, smoother
        //   - Higher detail (2.0): octaveFactor ≈ 0.45, more high-freq content, finer detail
        float freq = uniforms.frequency;
        float baseAmplitude = uniforms.turbulence * uniforms.frequency;
        float octaveFactor = mix(0.75, 0.45, (uniforms.detail - 0.5) / 1.5);
        for (int turbLoop = 0; turbLoop < 8; turbLoop++) {
            float3 offset = float3(t * 10.0, t, freq);
            p += cos((p.yzx - offset) * freq) * baseAmplitude / freq;
            freq = freq / octaveFactor;
        }

        // Hollow cone distance approximation with configurable width and taper
        // coneRadius: actual distance from the center axis
        float coneRadius = length(p.xz);

        // baseWidth directly controls the width at the bottom of the flame
        // At max (2.0), flame spans full window width; at min (0.3), small flame in center
        float baseRadius = uniforms.baseWidth * 0.5;

        // Flame base - calculated from actual convergence zone
        // Empirical analysis shows convergence at z≈5, not z=3
        // At z=5: bottom screen (uv.y=-1) samples p.y=-2.887
        float flameBase = -2.887;

        // Flame top is determined by height parameter
        // Screen range at z=5: -2.887 to 4.887 = 7.774 units
        // height=1.0 should fill full screen, so multiply by screen range
        float flameTop = flameBase + uniforms.height * 7.774;

        // Calculate target radius based on position (use original Y before turbulence)
        float targetRadius;

        if (pYOriginal <= flameTop) {
            // Within flame height: interpolate between base and top
            float heightFactor = clamp((pYOriginal - flameBase) / (flameTop - flameBase), 0.0, 1.0);

            // Taper controls the width at the flame top
            // taper=0: point at top (topRadius=0)
            // taper=0.5: same width as base (topRadius=baseRadius) - cylinder
            // taper=1.0: twice the base width (topRadius=2*baseRadius) - expanding cone
            float topRadius = uniforms.taper * 2.0 * baseRadius;

            // Width at any vertical position interpolates between base and top
            targetRadius = mix(baseRadius, topRadius, heightFactor);
            targetRadius = max(targetRadius, 0.02);
        } else {
            // Above flame top: shrink cone to zero over a short distance
            float fadeHeight = 0.3;  // Distance over which to shrink to zero
            float topRadius = uniforms.taper * 2.0 * baseRadius;
            float shrinkFactor = 1.0 - clamp((pYOriginal - flameTop) / fadeHeight, 0.0, 1.0);
            targetRadius = topRadius * shrinkFactor;
            targetRadius = max(targetRadius, 0.001);  // Very small to prevent accumulation
        }

        float dist = 0.01 + abs(coneRadius - targetRadius) / 7.0;
        z += dist;

        // Color accumulation with attenuation
        // Enhanced brightness variation for volumetric strand effect
        // Use multiple frequency variations to create depth and strands
        float brightVariation = sin(z / 3.0) * 0.5 +
                                sin(z / 1.5) * 0.3 +
                                cos(z / 2.0 + t) * 0.2;

        // Color variation for creating distinct strands
        float colorVariation = sin(z / 2.0) * cos(z / 4.0);

        // Normalize temperature from [0.5, 2.0] to [0.0, 1.0] for variation control
        float tempNorm = clamp((uniforms.colorShift - 0.5) / 1.5, 0.0, 1.0);

        // Get base color from temperature with variation for color strands
        float3 baseColor = temperatureToColor(uniforms.colorShift, colorVariation);

        // Add brightness variation that scales with temperature
        // Higher temperatures get more variation for a more energetic look
        float variationStrength = mix(0.6, 1.4, tempNorm); // Lower temps: 0.6-1.4, Higher temps: broader range
        float brightness = variationStrength + brightVariation * 0.4;
        brightness = max(brightness, 0.2); // Ensure we don't go too dark

        // Apply brightness to color
        float3 color = baseColor * brightness / dist;

        // Height fade: smoothly fade out the flame at the top (use original Y)
        float topFadeWidth = max((flameTop - flameBase) * 0.3, 0.3);
        float topFadeStart = flameTop - topFadeWidth;
        float heightFade = 1.0 - smoothstep(topFadeStart, flameTop, pYOriginal);

        O.rgb += color * uniforms.intensity * heightFade;
        O.a += uniforms.intensity / dist * heightFade;
    }

    // Tone mapping
    O = tanhApprox(O / 1000.0);

    // Ensure alpha is 1.0
    O.a = 1.0;

    // Write to output texture
    outTexture.write(O, gid);
}
