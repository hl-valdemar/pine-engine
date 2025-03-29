const std = @import("std");
const sokol = @import("sokol");

const Light = @import("lighting/light.zig").Light;

const math = @import("math.zig");
const Mat4 = math.Mat4;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;

pub const AttributeSlots = struct {
    pub const POSITION = 0;
    pub const NORMALS = 1;
    pub const COLOR_0 = 2;
};

pub const VsParams = struct {
    model: Mat4,
    view: Mat4,
    projection: Mat4,
};

pub const FsParams = struct {
    light_color: Vec3,
    light_direction: Vec3,
    view_position: Vec3,
};

pub const Shader = struct {
    allocator: std.mem.Allocator,
    label: []const u8,
    vs_source: []const u8,
    fs_source: []const u8,
    shader: sokol.gfx.Shader,
    pipeline: sokol.gfx.Pipeline,

    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        vertex_source: []const u8,
        fragment_source: []const u8,
        backend: sokol.gfx.Backend,
    ) !Shader {
        const vs_source_copy = try allocator.dupeZ(u8, vertex_source);
        errdefer allocator.free(vs_source_copy);

        const fs_source_copy = try allocator.dupeZ(u8, fragment_source);
        errdefer allocator.free(fs_source_copy);

        const label_copy = try allocator.dupeZ(u8, label);
        errdefer allocator.free(label_copy);

        var shader_desc = sokol.gfx.ShaderDesc{};
        shader_desc.label = label_copy;
        switch (backend) {
            .METAL_MACOS => {
                shader_desc.vertex_func.source = vs_source_copy;
                shader_desc.vertex_func.entry = "vs_main";

                shader_desc.fragment_func.source = fs_source_copy;
                shader_desc.fragment_func.entry = "fs_main";

                shader_desc.uniform_blocks[0].stage = .VERTEX;
                shader_desc.uniform_blocks[0].layout = .STD140;
                shader_desc.uniform_blocks[0].msl_buffer_n = 0;
                shader_desc.uniform_blocks[0].size = @sizeOf(VsParams);

                shader_desc.uniform_blocks[1].stage = .FRAGMENT;
                shader_desc.uniform_blocks[1].layout = .STD140;
                shader_desc.uniform_blocks[1].msl_buffer_n = 1;
                shader_desc.uniform_blocks[1].size = @sizeOf(FsParams);
            },
            else => @panic("PLATFORM NOT SUPPORTED!\n"),
        }

        const shader = sokol.gfx.makeShader(shader_desc);
        errdefer sokol.gfx.destroyShader(shader);

        const layout: sokol.gfx.VertexLayoutState = blk: {
            var l = sokol.gfx.VertexLayoutState{};
            l.attrs[AttributeSlots.POSITION].format = .FLOAT3;
            l.attrs[AttributeSlots.POSITION].buffer_index = 0;

            l.attrs[AttributeSlots.NORMALS].format = .FLOAT3;
            l.attrs[AttributeSlots.NORMALS].buffer_index = 1;

            l.attrs[AttributeSlots.COLOR_0].format = .FLOAT4;
            l.attrs[AttributeSlots.COLOR_0].buffer_index = 0;
            break :blk l;
        };

        const pipeline = sokol.gfx.makePipeline(.{
            .label = label_copy,
            .shader = shader,
            .layout = layout,
            .index_type = .UINT32,
            .cull_mode = .NONE,
            .face_winding = .CW,
            .depth = .{
                .write_enabled = true,
                .compare = .LESS_EQUAL,
            },
        });
        errdefer sokol.gfx.destroyPipeline(pipeline);

        return .{
            .allocator = allocator,
            .label = label_copy,
            .vs_source = vs_source_copy,
            .fs_source = fs_source_copy,
            .shader = shader,
            .pipeline = pipeline,
        };
    }

    pub fn deinit(self: *const Shader) void {
        sokol.gfx.destroyShader(self.shader);
        sokol.gfx.destroyPipeline(self.pipeline);
        self.allocator.free(self.vs_source);
        self.allocator.free(self.fs_source);
        self.allocator.free(self.label);
    }
};
