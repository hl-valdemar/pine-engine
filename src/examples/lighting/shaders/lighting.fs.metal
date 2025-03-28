#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct FsParams
{
    float3 light_color;
    float3 light_direction;
    float3 view_position;
};

struct MainIn
{
    float4 color0 [[user(locn0)]];
    float3 normal [[user(locn1)]];
    float3 world_position [[user(locn2)]];
};

fragment float4 fs_main(MainIn in [[stage_in]], constant FsParams& params [[buffer(1)]])
{
    // ambient
    float ambient_strength = 0.1;
    float3 ambient = ambient_strength * params.light_color;

    // diffuse
    float3 normal = normalize(in.normal);
    //float3 light_dir = normalize(params.light_direction);
    float3 light_dir = normalize(float3(0.0, 1.0, 0.0));
    float diff = max(dot(normal, light_dir), 0.0);
    float3 diffuse = diff * in.color0.rgb;

    // specular
    float specular_strength = 0.5;
    float3 view_dir = normalize(params.view_position - in.world_position);
    float3 reflect_dir = reflect(-light_dir, normal);
    float spec = pow(max(dot(view_dir, reflect_dir), 0.0), 2);
    float3 specular = specular_strength * spec * params.light_color;

    // comprised light
    float3 result = (ambient + diffuse + specular) * in.color0.rgb;

    return float4(result, in.color0.a);
}
