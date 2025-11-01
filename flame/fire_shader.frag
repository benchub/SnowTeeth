//
//  fire_shader.frag
//  3D Fire Shader for Android
//
//  OpenGL ES 3.0 fragment shader implementation
//

#version 300 es
precision highp float;

uniform float u_time;
uniform float u_speed;
uniform float u_intensity;
uniform float u_height;
uniform float u_turbulence;
uniform float u_detail;
uniform float u_colorShift;
uniform float u_baseWidth;
uniform float u_taper;
uniform float u_twist;
uniform float u_frequency;
uniform float u_timeOffset;
uniform vec2 u_resolution;

out vec4 fragColor;

// Tanh approximation for tone mapping
vec4 tanhApprox(vec4 x) {
    vec4 x2 = x * x;
    return x * (3.0 + x2) / (3.0 + 3.0 * x2);
}

// Temperature-based color mapping with improved contrast
// Maps temperature value to flame colors: red → orange → yellow → green → cyan → blue → white
vec3 temperatureToColor(float temp, float variation) {
    // Normalize temperature from [0.5, 2.0] to [0.0, 1.0]
    float t = clamp((temp - 0.5) / 1.5, 0.0, 1.0);

    // Add subtle variation to the temperature to create color strands
    t += variation * 0.05;
    t = clamp(t, 0.0, 1.0);

    // Define color stops with better saturation for volumetric effect
    vec3 red = vec3(1.0, 0.0, 0.0);
    vec3 orange = vec3(1.0, 0.4, 0.0);
    vec3 yellow = vec3(1.0, 0.9, 0.0);
    vec3 green = vec3(0.0, 0.5, 0.1);  // Darker green for better strand contrast
    vec3 cyan = vec3(0.0, 0.8, 1.0);
    vec3 blue = vec3(0.2, 0.4, 1.0);
    vec3 white = vec3(1.0, 1.0, 1.0);

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

void main() {
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 iResolution = u_resolution;

    // Center the coordinates and normalize to [-1, 1] range
    // Flip Y to make flame point upward
    vec2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;
    uv.y = -uv.y;

    float t = u_timeOffset;  // Use integrated time for phase continuity
    float z = 0.0;
    vec4 O = vec4(0.0);

    // 50-iteration raymarch loop
    for(float step = 0.0; step < 50.0; step++) {
        // Ray sample computation with animation
        vec3 p = z * normalize(vec3(uv, -1.0));
        p.z += 5.0 + cos(t) * 0.5;

        // Shift p.y so bottom of screen samples p.y=0, top samples p.y=2
        // After flip: uv.y = +1 at TOP (rays go UP), -1 at BOTTOM (rays go DOWN)
        p.y += uv.y + 1.0;

        // Save original p.y for height/taper calculations (before turbulence)
        float pYOriginal = p.y;

        // Matrix rotation with twist effect
        // Twist parameter controls how much the flame spirals (0 = no twist, higher values = more spiral)
        float angle = p.y * 0.5 * u_twist;
        float cosVal = cos(angle);
        float sinVal = sin(angle);
        mat2 rotMat = mat2(cosVal, -sinVal, sinVal, cosVal);

        // Apply fixed scaling factor to prevent corner artifacts with rotation
        float scaleFactor = max(p.y * 0.15 + 1.0, 0.5);
        p.xz = (rotMat * p.xz) / scaleFactor;

        // 8-loop turbulence with frequency scaling
        // turbulence: amplitude (width of displacement)
        // frequency: base wavelength (vertical spacing between kinks)
        // detail: octave scaling factor (how much fine detail is added)
        //   - Lower detail (0.5): octaveFactor ≈ 0.75, less high-freq content, smoother
        //   - Higher detail (2.0): octaveFactor ≈ 0.45, more high-freq content, finer detail
        float freq = u_frequency;
        float baseAmplitude = u_turbulence * u_frequency;
        float octaveFactor = mix(0.75, 0.45, (u_detail - 0.5) / 1.5);
        for(int turbLoop = 0; turbLoop < 8; turbLoop++) {
            vec3 offset = vec3(t * 10.0, t, freq);
            p += cos((p.yzx - offset) * freq) * baseAmplitude / freq;
            freq = freq / octaveFactor;
        }

        // Hollow cone distance approximation with configurable width and taper
        // coneRadius: actual distance from the center axis
        float coneRadius = length(p.xz);

        // baseWidth directly controls the width at the bottom of the flame
        // At max (2.0), flame spans full window width; at min (0.3), small flame in center
        float baseRadius = u_baseWidth * 0.5;

        // Flame base - calculated from actual convergence zone
        // Empirical analysis shows convergence at z≈5, not z=3
        // At z=5: bottom screen (uv.y=-1) samples p.y=-2.887
        float flameBase = -2.887;

        // Flame top is determined by height parameter
        // Screen range at z=5: -2.887 to 4.887 = 7.774 units
        // height=1.0 should fill full screen, so multiply by screen range
        float flameTop = flameBase + u_height * 7.774;

        // Calculate target radius based on position (use original Y before turbulence)
        float targetRadius;

        if (pYOriginal <= flameTop) {
            // Within flame height: interpolate between base and top
            float heightFactor = clamp((pYOriginal - flameBase) / (flameTop - flameBase), 0.0, 1.0);

            // Taper controls the width at the flame top
            // taper=0: point at top (topRadius=0)
            // taper=0.5: same width as base (topRadius=baseRadius) - cylinder
            // taper=1.0: twice the base width (topRadius=2*baseRadius) - expanding cone
            float topRadius = u_taper * 2.0 * baseRadius;

            // Width at any vertical position interpolates between base and top
            targetRadius = mix(baseRadius, topRadius, heightFactor);
            targetRadius = max(targetRadius, 0.02);
        } else {
            // Above flame top: shrink cone to zero over a short distance
            float fadeHeight = 0.3;  // Distance over which to shrink to zero
            float topRadius = u_taper * 2.0 * baseRadius;
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
        float tempNorm = clamp((u_colorShift - 0.5) / 1.5, 0.0, 1.0);

        // Get base color from temperature with variation for color strands
        vec3 baseColor = temperatureToColor(u_colorShift, colorVariation);

        // Add brightness variation that scales with temperature
        // Higher temperatures get more variation for a more energetic look
        float variationStrength = mix(0.6, 1.4, tempNorm); // Lower temps: 0.6-1.4, Higher temps: broader range
        float brightness = variationStrength + brightVariation * 0.4;
        brightness = max(brightness, 0.2); // Ensure we don't go too dark

        // Apply brightness to color
        vec3 color = baseColor * brightness / dist;

        // Height fade: smoothly fade out the flame at the top (use original Y)
        float topFadeWidth = max((flameTop - flameBase) * 0.3, 0.3);
        float topFadeStart = flameTop - topFadeWidth;
        float heightFade = 1.0 - smoothstep(topFadeStart, flameTop, pYOriginal);

        O.rgb += color * u_intensity * heightFade;
        O.a += u_intensity / dist * heightFade;
    }

    // Tone mapping
    O = tanhApprox(O / 1000.0);

    // Ensure alpha is 1.0
    O.a = 1.0;

    fragColor = O;
}
