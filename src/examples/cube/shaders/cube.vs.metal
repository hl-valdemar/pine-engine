#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct vs_params
{
    float4x4 mvp;
};

struct main_out
{
    float4 color0 [[user(locn0)]];
    float4 position [[position]];
};

struct main_in
{
    float4 position [[attribute(0)]];
    float4 color0 [[attribute(1)]];
};

vertex main_out _main(main_in in [[stage_in]], constant vs_params& vs_p [[buffer(0)]])
{
    main_out out = {};
    out.position = vs_p.mvp * in.position;
    out.color0 = in.color0;
    return out;
}
