#include <metal_stdlib>
using namespace metal;
struct vs_params {
    float4x4 mvp;
};
struct vs_in {
    float3 position [[attribute(0)]];
    float4 color0 [[attribute(1)]];
};
struct vs_out {
    float4 position [[position]];
    float4 color0 [[user(locn0)]];
};
vertex vs_out _main(vs_in in [[stage_in]], constant vs_params& params [[buffer(0)]]) {
    vs_out out;
    out.position = params.mvp * float4(in.position, 1.0);
    out.color0 = in.color0;
    return out;
}
