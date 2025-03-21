const std = @import("std");

const Mat4 = @import("math.zig").Mat4;

pub const Material = struct {
    allocator: std.mem.Allocator,
    label: []const u8,
    shader_label: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        shader_label: []const u8,
    ) !Material {
        const label_copy = try allocator.dupe(u8, label);
        errdefer allocator.free(label_copy);

        const shader_label_copy = try allocator.dupe(u8, shader_label);
        errdefer allocator.free(shader_label_copy);

        return .{
            .allocator = allocator,
            .label = label_copy,
            .shader_label = shader_label_copy,
        };
    }

    pub fn deinit(self: *Material) void {
        self.allocator.free(self.label);
        self.allocator.free(self.shader_label);
    }
};
