#include <metal_stdlib>
using namespace metal;
struct fs_in {
    float4 color0 [[user(locn0)]];
};
fragment float4 _main(fs_in in [[stage_in]]) {
    return in.color0;
}
