const sokol = @import("sokol");

pub const Material = struct {
    shader: sokol.gfx.Shader,
    pipeline: sokol.gfx.Pipeline,

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
        };
    }

    pub fn deinit(self: *const Material) void {
        // NOTE: the shader is not our responsibility, as it was passed on initialization
        sokol.gfx.destroyPipeline(self.pipeline);
    }
};
