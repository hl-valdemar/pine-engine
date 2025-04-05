#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct VsParams {
    float4x4 model;
    float4x4 view;
    float4x4 projection;
};

struct MainOut {
    float4 position [[position]];
    float4 color0 [[user(locn0)]];
    float3 world_pos [[user(locn1)]];
    float3 normal [[user(locn2)]];
};

struct MainIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color0 [[attribute(2)]];
    float3 texcoord0 [[attribute(3)]];
};

vertex MainOut vs_main(MainIn in [[stage_in]], constant VsParams& params [[buffer(0)]]) {
    MainOut out;

    float4x4 mvp = params.projection * params.view * params.model;
    out.position = mvp * float4(in.position, 1.0);
    out.color0 = in.color0;

    return out;
}
