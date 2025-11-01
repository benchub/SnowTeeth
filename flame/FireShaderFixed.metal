//
//  FireShaderFixed.metal
//  3D Fire Shader for iOS/macOS - Fixed Version
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
    float colorShift;
    float2 resolution;
};

// Tanh approximation for tone mapping
float4 tanhApprox(float4 x) {
    float4 x2 = x * x;
    return x * (3.0 + x2) / (3.0 + 3.0 * x2);
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

    // Center the coordinates and normalize
    float2 uv = (fragCoord * 2.0 - iResolution) / iResolution.y;

    float t = uniforms.time * uniforms.speed;
    float z = 0.0;
    float4 O = float4(0.0);

    // 50-iteration raymarch loop
    for (float step = 0.0; step < 50.0; step++) {
        // Ray sample computation with animation
        float3 p = z * normalize(float3(uv, -1.0));
        p.z += 5.0 + cos(t) * uniforms.height;

        // Matrix rotation with twist effect
        float angle = p.y * 0.5;
        float cosVal = cos(angle);
        float sinVal = sin(angle);
        float2x2 rotMat = float2x2(cosVal, -sinVal, sinVal, cosVal);
        p.xz = (rotMat * p.xz) / max(p.y * 0.1 + 1.0, 0.1);

        // 8-loop turbulence with frequency scaling
        float freq = 2.0;
        for (int turbLoop = 0; turbLoop < 8; turbLoop++) {
            float3 offset = float3(t * 10.0, t, freq);
            p += cos((p.yzx - offset) * freq * uniforms.turbulence) / freq;
            freq = freq / 0.6;
        }

        // Hollow cone distance approximation
        float dist = 0.01 + abs(length(p.xz) + p.y * 0.3 - 0.5) / 7.0;
        z += dist;

        // Color accumulation with attenuation
        float4 colorOffset = float4(7, 2, 3, 0) * uniforms.colorShift;
        float4 color = (sin(z / 3.0 + colorOffset) + 1.1) / dist;
        O += color * uniforms.intensity;
    }

    // Tone mapping
    O = tanhApprox(O / 1000.0);

    // Ensure alpha is 1
    O.a = 1.0;

    // Write to output texture
    outTexture.write(O, gid);
}
