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
    float3 normal [[user(locn1)]];
    float3 frag_pos [[user(locn2)]];
};

struct MainIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color0 [[attribute(2)]];
};

vertex MainOut vs_main(MainIn in [[stage_in]], constant VsParams& params [[buffer(0)]]) {
    MainOut out;

    float4x4 mvp = params.projection * params.view * params.model;

    out.position = mvp * float4(in.position, 1.0);

    // transform position and normal for lighting
    out.frag_pos = (params.model * float4(in.position, 1.0)).xyz;
    
    // normal matrix (transpose of inverse of model matrix, simplified for uniform scaling)
    float3x3 normal_matrix = float3x3(
        params.model[0].xyz, 
        params.model[1].xyz, 
        params.model[2].xyz
    );
    out.normal = normalize(normal_matrix * float4(in.normal, 0).xyz);

    out.color0 = in.color0;
    
    return out;
}
