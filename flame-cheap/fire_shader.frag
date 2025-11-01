//
//  fire_shader.frag
//  2D Fire Shader for Android
//
//  OpenGL ES 3.0 fragment shader implementation
//  Based on "One-Pass Fire" by @XorDev
//

#version 300 es
precision highp float;

uniform float u_intensity;
uniform float u_height;
uniform float u_colorShift;
uniform float u_baseWidth;
uniform float u_timeOffset;
uniform vec2 u_resolution;
uniform sampler2D u_noiseTexture;
uniform float u_colorBlend;

out vec4 fragColor;

// Apply turbulence to coordinates
vec2 turbulence(vec2 p, float iTime, float turbFreq, float turbNum, float turbSpeed, float turbAmp, float turbExp) {
    // Turbulence starting scale
    float freq = turbFreq;

    // Turbulence rotation matrix
    mat2 rot = mat2(0.6, -0.8, 0.8, 0.6);

    // Loop through turbulence octaves
    for(float i = 0.0; i < turbNum; i += 1.0) {
        // Scroll along the rotated y coordinate
        vec2 rotP = p * rot;
        float phase = freq * rotP.y + turbSpeed * iTime + i;
        // Add a perpendicular sine wave offset
        p += turbAmp * rot[0] * sin(phase) / freq;

        // Rotate for the next octave
        rot = rot * mat2(0.6, -0.8, 0.8, 0.6);
        // Scale down for the next octave
        freq *= turbExp;
    }

    return p;
}

// Temperature-based color mapping (optimized with constants and smoothstep)
vec3 temperatureToColor(float temp) {
    float t = clamp((temp - 0.5) / 1.5, 0.0, 1.0);

    // Use smoothstep blending instead of branching for better GPU performance
    float t5 = t * 5.0;  // Map [0,1] to [0,5] for 5 color zones

    // Color constants
    const vec3 orange = vec3(1.0, 0.5, 0.0);
    const vec3 yellow = vec3(1.0, 0.9, 0.0);
    const vec3 green = vec3(0.0, 1.0, 0.0);
    const vec3 cyan = vec3(0.0, 0.8, 1.0);
    const vec3 blue = vec3(0.0, 0.3, 1.0);
    const vec3 white = vec3(1.0, 1.0, 1.0);

    // Branchless color interpolation
    vec3 col = orange;
    col = mix(col, yellow, smoothstep(0.0, 1.0, t5));
    col = mix(col, green, smoothstep(1.0, 2.0, t5));
    col = mix(col, cyan, smoothstep(2.0, 3.0, t5));
    col = mix(col, blue, smoothstep(3.0, 4.0, t5));
    col = mix(col, white, smoothstep(4.0, 5.0, t5));

    return col;
}

void main() {
    vec2 fragCoord = gl_FragCoord.xy;
    vec2 iResolution = u_resolution;
    float iTime = u_timeOffset;

    // Algorithm parameters (configurable via uniforms)
    float RADIUS = 0.4 * u_height;  // Height controls flame size
    float GRADIENT = 0.3;
    float SCROLL = 1.6;  // Speed is controlled via timeOffset integration in Swift
    float scrollTime = SCROLL * iTime;  // Cache this calculation

    float TURB_NUM = 8.0;  // Reduced from 10 for performance
    float TURB_AMP = 0.4;
    float TURB_SPEED = 6.0;  // Speed is controlled via timeOffset integration
    float TURB_FREQ = 7.0;
    float TURB_EXP = 1.3;

    // Screen coordinates, centered and aspect corrected
    vec2 p = (fragCoord * 2.0 - iResolution) / iResolution.y;

    // Flip Y so flame burns upward
    p.y = -p.y;

    // Apply width control
    p.x /= u_baseWidth;

    // Expand vertically
    float xstretch = 2.0 - 1.5 * smoothstep(-2.0, 2.0, p.y);
    // Decelerate horizontally
    float ystretch = 1.0 - 0.5 / (1.0 + p.x * p.x);
    // Combine
    vec2 stretch = vec2(xstretch, ystretch);
    // Stretch coordinates
    p *= stretch;

    // Scroll upward
    p.y -= scrollTime;

    p = turbulence(p, iTime, TURB_FREQ, TURB_NUM, TURB_SPEED, TURB_AMP, TURB_EXP);

    // Reverse the scrolling offset
    p.y += scrollTime;

    // Distance to fireball
    float dist = length(min(p, p / vec2(1, stretch.y))) - RADIUS;
    // Attenuate outward and fade vertically (optimized pow to multiplication)
    float distSq = dist * dist + GRADIENT * max(p.y + 0.5, 0.0);
    float light = 1.0 / (distSq * distSq * distSq);
    // Coordinates relative to the source
    vec2 source = p + 2.0 * vec2(0, RADIUS) * stretch;

    // Temperature-based color with edge blending
    vec3 coreColor = temperatureToColor(u_colorShift);
    vec3 edgeColor = vec3(1.0, 0.2, 0.0);  // Red-orange edge

    // Blend from core to edge based on distance from center
    float centerDist = length(source);
    float colorMix = smoothstep(0.0, u_colorBlend, centerDist);
    vec3 flameColor = mix(coreColor, edgeColor, colorMix);

    // Use uniform falloff to preserve colors
    float falloff = 0.1 / (1.0 + centerDist * 2.0);
    vec3 grad = flameColor * falloff;

    // Ambient lighting (no flicker) - optimized to reuse dot product
    float pDotP = dot(p, p);
    vec3 amb = 16.0 / (1.0 + pDotP) * grad;

    // Scrolling texture uvs (reuse scrollTime)
    vec2 uv = (p - vec2(0, scrollTime)) / 100.0 * TURB_FREQ;
    // Sample texture for fire
    vec3 tex = texture(u_noiseTexture, uv).rgb;

    // Combine ambient and direct fire
    vec3 col = amb + light * grad * tex * u_intensity;
    // Exponential tonemap
    col = 1.0 - exp(-col);

    fragColor = vec4(col, 1.0);
}
