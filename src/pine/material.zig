const std = @import("std");

const Mat4 = @import("math.zig").Mat4;

pub const Material = struct {
    allocator: std.mem.Allocator,
    label: []const u8,
    shader_label: []const u8,
    // uniforms: std.AutoHashMap(UniformType, UniformData),
    transform_label: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        shader_label: []const u8,
        transform_label: []const u8,
    ) !Material {
        const label_copy = try allocator.dupe(u8, label);
        errdefer allocator.free(label_copy);

        const shader_label_copy = try allocator.dupe(u8, shader_label);
        errdefer allocator.free(shader_label_copy);

        const transform_label_copy = try allocator.dupe(u8, transform_label);
        errdefer allocator.free(transform_label_copy);

        return .{
            .allocator = allocator,
            .label = label_copy,
            .shader_label = shader_label_copy,
            .transform_label = transform_label_copy,
            // .uniforms = std.AutoHashMap(UniformType, UniformData).init(allocator),
        };
    }

    pub fn deinit(self: *Material) void {
        // self.uniforms.deinit();
        self.allocator.free(self.label);
        self.allocator.free(self.shader_label);
        self.allocator.free(self.transform_label);
    }
};

pub const UniformType = enum {
    mvp,
};

pub const UniformData = union(UniformType) {
    mvp: Mat4 align(16), // NOTE: a hardcoded alignment of 16 may be too restrictive in some cases
};
