#include <metal_stdlib>
using namespace metal;

struct FragmentIn {
    float4 color0 [[user(locn0)]];
};

fragment float4 fs_main(FragmentIn in [[stage_in]]) {
    return in.color0;
}
