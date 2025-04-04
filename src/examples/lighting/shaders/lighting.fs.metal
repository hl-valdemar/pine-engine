#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct LightProperties {
    float3 direction;
    float3 color;
    float intensity;
};

struct FsParams {
    LightProperties light_properties;
    float3 camera_pos;
};

struct MainIn {
    float4 color0 [[user(locn0)]];
    float3 normal [[user(locn1)]];
    float3 frag_pos [[user(locn2)]];
};

fragment float4 fs_main(MainIn in [[stage_in]], constant FsParams& params [[buffer(1)]]) {
    float3 light_dir = normalize(-params.light_properties.direction);
    float3 light_color = params.light_properties.color * params.light_properties.intensity;

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
    float specular_strength = 0.0;
    float3 specular = specular_strength * spec * params.light_properties.color;
    
    float3 blin_phong = (ambient + diffuse) * in.color0.rgb + specular;

    // gamma correction
    //float gamma = 1.25;
    //float3 result = pow(blin_phong, float3(1 / gamma));

    return float4(blin_phong, in.color0.a);
}
