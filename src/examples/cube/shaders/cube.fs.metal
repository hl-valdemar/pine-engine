#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct FsParams {
    float4 color_intensities;
};

struct MainOut
{
    float4 color0 [[color(0)]];
};

struct MainIn
{
    float4 color0 [[user(locn0)]];
};

fragment MainOut fs_main(MainIn in [[stage_in]], constant FsParams& params [[buffer(1)]])
{
    MainOut out = {};
    out.color0 = in.color0 * params.color_intensities;
    return out;
}
