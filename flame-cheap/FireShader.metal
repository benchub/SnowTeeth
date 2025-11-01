//
//  FireShader.metal
//  2D Fire Shader for iOS/macOS
//
//  Metal implementation of simple 2D fire effect
//  Based on "One-Pass Fire" by @XorDev
//

#include <metal_stdlib>
using namespace metal;

struct FireUniforms {
    float intensity;
    float height;
    float colorShift;
    float baseWidth;
    float timeOffset;
    float2 resolution;
    float colorBlend;
};

// Apply turbulence to coordinates
float2 turbulence(float2 p, float iTime, float turbFreq, float turbNum, float turbSpeed, float turbAmp, float turbExp) {
    // Turbulence starting scale
    float freq = turbFreq;

    // Turbulence rotation matrix
    float2x2 rot = float2x2(0.6, -0.8, 0.8, 0.6);

    // Loop through turbulence octaves
    for(float i = 0.0; i < turbNum; i += 1.0) {
        // Scroll along the rotated y coordinate
        float2 rotP = float2(dot(p, float2(rot[0][0], rot[1][0])),
                              dot(p, float2(rot[0][1], rot[1][1])));
        float phase = freq * rotP.y + turbSpeed * iTime + i;
        // Add a perpendicular sine wave offset
        p += turbAmp * float2(rot[0][0], rot[0][1]) * sin(phase) / freq;

        // Rotate for the next octave
        float2x2 newRot = float2x2(
            rot[0][0] * 0.6 - rot[0][1] * 0.8,
            rot[0][0] * 0.8 + rot[0][1] * 0.6,
            rot[1][0] * 0.6 - rot[1][1] * 0.8,
            rot[1][0] * 0.8 + rot[1][1] * 0.6
        );
        rot = newRot;
        // Scale down for the next octave
        freq *= turbExp;
    }

    return p;
}

// Temperature-based color mapping (optimized with constants and smoothstep)
float3 temperatureToColor(float temp) {
    float t = clamp((temp - 0.5) / 1.5, 0.0, 1.0);

    // Use smoothstep blending instead of branching for better GPU performance
    float t5 = t * 5.0;  // Map [0,1] to [0,5] for 5 color zones

    // Color constants (compiler will optimize these)
    float3 orange = float3(1.0, 0.5, 0.0);
    float3 yellow = float3(1.0, 0.9, 0.0);
    float3 green = float3(0.0, 1.0, 0.0);
    float3 cyan = float3(0.0, 0.8, 1.0);
    float3 blue = float3(0.0, 0.3, 1.0);
    float3 white = float3(1.0, 1.0, 1.0);

    // Branchless color interpolation
    float3 col = orange;
    col = mix(col, yellow, smoothstep(0.0, 1.0, t5));
    col = mix(col, green, smoothstep(1.0, 2.0, t5));
    col = mix(col, cyan, smoothstep(2.0, 3.0, t5));
    col = mix(col, blue, smoothstep(3.0, 4.0, t5));
    col = mix(col, white, smoothstep(4.0, 5.0, t5));

    return col;
}

kernel void fireShader(texture2d<float, access::write> outTexture [[texture(0)]],
                       texture2d<float> noiseTexture [[texture(1)]],
                       constant FireUniforms &uniforms [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    float2 fragCoord = float2(gid);
    float2 iResolution = uniforms.resolution;

    // Skip if out of bounds
    if (fragCoord.x >= iResolution.x || fragCoord.y >= iResolution.y) {
        return;
    }

    float iTime = uniforms.timeOffset;

    // Create sampler for noise texture
    constexpr sampler noiseSampler(mag_filter::linear, min_filter::linear, address::repeat);

    // Algorithm parameters (configurable via uniforms)
    float RADIUS = 0.4 * uniforms.height;  // Height controls flame size
    float GRADIENT = 0.3;
    float SCROLL = 1.6;  // Speed is controlled via timeOffset integration in Swift
    float scrollTime = SCROLL * iTime;  // Cache this calculation

    float TURB_NUM = 8.0;  // Reduced from 10 for performance
    float TURB_AMP = 0.4;
    float TURB_SPEED = 6.0;  // Speed is controlled via timeOffset integration
    float TURB_FREQ = 7.0;
    float TURB_EXP = 1.3;

    // Screen coordinates, centered and aspect corrected
    float2 p = (fragCoord * 2.0 - iResolution) / iResolution.y;

    // Flip Y so flame burns upward
    p.y = -p.y;

    // Apply width control
    p.x /= uniforms.baseWidth;

    // Expand vertically
    float xstretch = 2.0 - 1.5 * smoothstep(-2.0, 2.0, p.y);
    // Decelerate horizontally
    float ystretch = 1.0 - 0.5 / (1.0 + p.x * p.x);
    // Combine
    float2 stretch = float2(xstretch, ystretch);
    // Stretch coordinates
    p *= stretch;

    // Scroll upward
    p.y -= scrollTime;

    p = turbulence(p, iTime, TURB_FREQ, TURB_NUM, TURB_SPEED, TURB_AMP, TURB_EXP);

    // Reverse the scrolling offset
    p.y += scrollTime;

    // Distance to fireball
    float dist = length(min(p, p / float2(1, stretch.y))) - RADIUS;
    // Attenuate outward and fade vertically (optimized pow to multiplication)
    float distSq = dist * dist + GRADIENT * max(p.y + 0.5, 0.0);
    float light = 1.0 / (distSq * distSq * distSq);
    // Coordinates relative to the source
    float2 source = p + 2.0 * float2(0, RADIUS) * stretch;

    // Temperature-based color with edge blending
    float3 coreColor = temperatureToColor(uniforms.colorShift);
    float3 edgeColor = float3(1.0, 0.2, 0.0);  // Red-orange edge

    // Blend from core to edge based on distance from center
    float centerDist = length(source);
    float colorMix = smoothstep(0.0, uniforms.colorBlend, centerDist);
    float3 flameColor = mix(coreColor, edgeColor, colorMix);

    // Use uniform falloff to preserve colors
    float falloff = 0.1 / (1.0 + centerDist * 2.0);
    float3 grad = flameColor * falloff;

    // Ambient lighting (no flicker) - optimized to reuse dot product
    float pDotP = dot(p, p);
    float3 amb = 16.0 / (1.0 + pDotP) * grad;

    // Scrolling texture uvs (reuse scrollTime)
    float2 uv = (p - float2(0, scrollTime)) / 100.0 * TURB_FREQ;
    // Sample texture for fire
    float3 tex = noiseTexture.sample(noiseSampler, uv).rgb;

    // Combine ambient and direct fire
    float3 col = amb + light * grad * tex * uniforms.intensity;
    // Exponential tonemap
    col = 1.0 - exp(-col);

    outTexture.write(float4(col, 1.0), gid);
}
