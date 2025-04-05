#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct FsParams {
    // todo
};

struct MainOut {
    float4 color0 [[color(0)]];
};

struct MainIn {
    float4 position [[position]];
    float4 color0 [[user(locn0)]];
};

fragment MainOut fs_main(
    MainIn in [[stage_in]],
    constant FsParams& params [[buffer(1)]],
    texture2d<float> previous_pass_texture [[texture(0)]],
    sampler texture_sampler [[sampler(0)]]
) {
    MainOut out;

    float2 tex_coord = in.position.xy / float2(previous_pass_texture.get_width(), previous_pass_texture.get_height());
    float4 previous_color = previous_pass_texture.sample(texture_sampler, tex_coord);
    float4 new_color = float4(0, 0, 1, 0.5);

    out.color0 = new_color + previous_color * (1 - new_color.a);

    return out;
}
