const sokol = @import("sokol");
const renderer = @import("renderer.zig");

pub const Material = struct {
    shader: sokol.gfx.Shader,
    pipeline: sokol.gfx.Pipeline,
    uniforms: UniformBlock,

    pub fn init(shader: sokol.gfx.Shader, layout: sokol.gfx.VertexLayoutState) Material {
        return .{
            .shader = shader,
            .pipeline = sokol.gfx.makePipeline(.{
                .label = "default-pipeline",
                .shader = shader,
                .layout = layout,
                .index_type = .UINT16,
                .cull_mode = .NONE,
                .depth = .{
                    .write_enabled = true,
                    .compare = .LESS_EQUAL,
                },
            }),
            .uniforms = .{},
        };
    }

    pub fn create_basic_shader() sokol.gfx.Shader {
        const vs_source =
            \\#include <metal_stdlib>
            \\using namespace metal;
            \\
            \\struct vs_in {
            \\    float3 position [[attribute(0)]];
            \\    float4 color [[attribute(1)]];
            \\};
            \\
            \\struct vs_out {
            \\    float4 position [[position]];
            \\    float4 color;
            \\};
            \\
            \\struct vs_params {
            \\    float4x4 model;
            \\    float4x4 view;
            \\    float4x4 projection;
            \\};
            \\
            \\vertex vs_out _main(vs_in in [[stage_in]], constant vs_params& params [[buffer(0)]]) {
            \\    vs_out out;
            \\    out.position = params.projection * params.view * params.model * float4(in.position, 1.0);
            \\    out.color = in.color;
            \\    return out;
            \\}
        ;
        const fs_source =
            \\#include <metal_stdlib>
            \\using namespace metal;
            \\
            \\struct fs_in {
            \\    float4 color;
            \\};
            \\
            \\fragment float4 _main(fs_in in [[stage_in]]) {
            \\    return in.color;
            \\}
        ;

        var shader_desc = sokol.gfx.ShaderDesc{
            .vs = .{ .source = vs_source },
            .fs = .{ .source = fs_source },
        };
        shader_desc.vs.uniform_blocks[0] = .{ .size = @sizeOf(renderer.VsParams) };
        shader_desc.vs.uniform_blocks[0].uniforms[0] = .{ .name = "model", .type = .MAT4 };
        shader_desc.vs.uniform_blocks[0].uniforms[1] = .{ .name = "view", .type = .MAT4 };
        shader_desc.vs.uniform_blocks[0].uniforms[2] = .{ .name = "projection", .type = .MAT4 };

        return sokol.gfx.makeShader(shader_desc);
    }
};

const UniformBlock = struct {};
