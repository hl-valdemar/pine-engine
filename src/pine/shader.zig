const std = @import("std");
const sokol = @import("sokol");

const LightProperties = @import("lighting/light.zig").LightProperties;

const resource_manager = @import("resource_manager.zig");
const UniqueID = resource_manager.UniqueID;
const UniqueIDType = resource_manager.UniqueIDType;

const math = @import("math.zig");
const Mat4 = math.Mat4;
const Vec4 = math.Vec4;
const Vec3 = math.Vec3;

pub const VsParams = extern struct {
    model: Mat4 align(16),
    view: Mat4 align(16),
    projection: Mat4 align(16),
};

pub const FsParams = extern struct {
    light_properties: LightProperties,
    camera_pos: Vec3 align(16),
};

pub const Shader = struct {
    allocator: std.mem.Allocator,

    label: []const u8,

    vs_source: []const u8,
    fs_source: []const u8,

    shader: sokol.gfx.Shader,

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

        var shader_desc = sokol.gfx.ShaderDesc{
            .label = label_copy,
        };
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

                shader_desc.images[0].stage = .FRAGMENT;
                shader_desc.images[0].image_type = ._2D;
                shader_desc.samplers[0].stage = .FRAGMENT;
                shader_desc.samplers[0].sampler_type = .FILTERING;

                shader_desc.image_sampler_pairs[0].stage = .FRAGMENT;
                shader_desc.image_sampler_pairs[0].image_slot = 0;
                shader_desc.image_sampler_pairs[0].sampler_slot = 0;
            },
            else => @panic("PLATFORM NOT SUPPORTED!\n"),
        }
        const shader = sokol.gfx.makeShader(shader_desc);
        errdefer sokol.gfx.destroyShader(shader);

        return Shader{
            .allocator = allocator,
            .label = label_copy,
            .vs_source = vs_source_copy,
            .fs_source = fs_source_copy,
            .shader = shader,
        };
    }

    pub fn deinit(self: *const Shader) void {
        sokol.gfx.destroyShader(self.shader);
        self.allocator.free(self.vs_source);
        self.allocator.free(self.fs_source);
        self.allocator.free(self.label);
    }
};

pub const ShaderPass = struct {
    shader_id: UniqueIDType = UniqueID.INVALID,
};
