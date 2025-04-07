#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

enum LightType {
    Directional = 0,
    Point = 1,
};

struct LightProperties {
    float3 position;
    float3 direction;
    float3 color;
    float intensity;
    bool is_active;
};

struct FsParams {
    LightType light_type;
    LightProperties light_props;
    float3 camera_pos;
};

struct MainIn {
    float4 position [[position]];
    float3 normal [[user(locn0)]];
    float4 color0 [[user(locn1)]];
    float3 frag_pos [[user(locn2)]];
};

fragment float4 fs_main(
    MainIn in [[stage_in]],
    constant FsParams& params [[buffer(1)]],
    texture2d<float> previous_pass_texture [[texture(0)]],
    sampler texture_sampler [[sampler(0)]]
) {
    float2 tex_coord = in.position.xy / float2(previous_pass_texture.get_width(), previous_pass_texture.get_height());
    float4 previous_color = previous_pass_texture.sample(texture_sampler, tex_coord);

    // make sure the light is active
    if (!params.light_props.is_active) {
        return previous_color;
    }

    // calculate light direction based on light type
    float3 light_dir;
    if (params.light_type == Directional) {
        light_dir = normalize(-params.light_props.direction);
    } else if (params.light_type == Point) {
        light_dir = normalize(params.light_props.position - in.frag_pos);
    }

    float3 light_color = params.light_props.color * params.light_props.intensity;

    // ambient
    float ambient_strength = 0.1;
    float3 ambient = ambient_strength * light_color;

    // diffuse
    float3 normal = normalize(in.normal);
    float diff = max(dot(normal, light_dir), 0.0);
    float3 diffuse = diff * light_color;

    // specular (Blinn-Phong)
    float3 view_dir = normalize(params.camera_pos - in.frag_pos);
    float3 halfway_dir = normalize(light_dir + view_dir);
    float spec = pow(max(dot(normal, halfway_dir), 0.0), 64.0); // higher exponent = sharper highlight
    float specular_strength = 0.5;
    float3 specular = specular_strength * spec * params.light_props.color;
    
    float3 blin_phong = (ambient + diffuse) * previous_color.rgb + specular;

    // gamma correction
    //float gamma = 1.25;
    //float3 result = pow(blin_phong, float3(1 / gamma));

    return float4(blin_phong, in.color0.a);
}
