const std = @import("std");

const Mat4 = @import("math.zig").Mat4;

const resource_mgr = @import("resource_manager.zig");
const UniqueIDType = resource_mgr.UniqueIDType;
const UniqueID = resource_mgr.UniqueID;

pub const Material = struct {
    allocator: std.mem.Allocator,

    label: []const u8,
    shader_id: UniqueIDType = UniqueID.INVALID,

    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        shader_id: UniqueIDType,
    ) !Material {
        const label_copy = try allocator.dupe(u8, label);
        errdefer allocator.free(label_copy);

        return .{
            .allocator = allocator,
            .label = label_copy,
            .shader_id = shader_id,
        };
    }

    pub fn deinit(self: *Material) void {
        self.allocator.free(self.label);
    }
};
