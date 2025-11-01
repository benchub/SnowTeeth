//
//  FireShaderDebug.metal
//  Debug version to test if Metal is working
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

kernel void fireShader(texture2d<float, access::write> outTexture [[texture(0)]],
                       constant FireUniforms &uniforms [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    float2 uv = float2(gid) / uniforms.resolution;

    // Simple test: output a gradient
    float4 testColor = float4(uv.x, uv.y, 0.5, 1.0);

    outTexture.write(testColor, gid);
}
