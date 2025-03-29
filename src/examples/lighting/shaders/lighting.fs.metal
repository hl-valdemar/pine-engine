#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct LightProperties
{
    float3 color;
    float intensity;
};

struct FsParams
{
    LightProperties light_properties;
    float3 camera_pos;
};

struct MainIn
{
    float4 color0 [[user(locn0)]];
    float3 normal [[user(locn1)]];
    float3 frag_pos [[user(locn2)]];
};

fragment float4 fs_main(MainIn in [[stage_in]], constant FsParams& params [[buffer(1)]])
{
    float3 light_dir = normalize(float3(0.0, -1.0, 0.0));

    // ambient
    float ambient_strength = 0.1;
    float3 ambient = ambient_strength * params.light_properties.color;

    // diffuse
    float3 normal = normalize(in.normal);
    float diff = max(dot(normal, -light_dir), 0.0);
    float3 diffuse = diff * in.color0.rgb;

    // specular (Blinn-Phong)
    float3 view_dir = normalize(params.camera_pos - in.frag_pos);
    float3 halfway_dir = normalize(-light_dir + view_dir);
    float spec = pow(max(dot(normal, halfway_dir), 0.0), 64.0); // higher exponent = sharper highlight
    float specular_strength = 0.05;
    float3 specular = specular_strength * spec * params.light_properties.color;
    
    float3 result = (ambient + diffuse) * in.color0.rgb + specular;
    return float4(result, in.color0.a);
}
