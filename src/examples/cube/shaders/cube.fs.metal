#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct main_out
{
    float4 color0 [[color(0)]];
};

struct main_in
{
    float4 color0 [[user(locn0)]];
};

fragment main_out _main(main_in in [[stage_in]])
{
    main_out out = {};
    out.color0 = in.color0;
    return out;
}
