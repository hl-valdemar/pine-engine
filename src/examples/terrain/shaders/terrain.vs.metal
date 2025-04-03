#include <metal_stdlib>
using namespace metal;

struct VsParams {
    float4x4 model;
    float4x4 view;
    float4x4 projection;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    //float3 normal [[attribute(1)]];
    float4 color0 [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color0 [[user(locn0)]];
};

vertex VertexOut vs_main(VertexIn in [[stage_in]], constant VsParams& params [[buffer(0)]]) {
    VertexOut out;

    float4x4 mvp = params.projection * params.view * params.model;
    out.position = mvp * float4(in.position, 1.0);
    out.color0 = in.color0;

    return out;
}
