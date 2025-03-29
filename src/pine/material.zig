const std = @import("std");

const math = @import("math.zig");
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;

const resource_mgr = @import("resource_manager.zig");
const UniqueIDType = resource_mgr.UniqueIDType;
const UniqueID = resource_mgr.UniqueID;

pub const MaterialProperties = struct {
    // PBR properties
    albedo: Vec3 = Vec3.ones(),
    metallic: f32 = 0.0,
    roughness: f32 = 0.5,
    ambient_occlusion: f32 = 1.0,
    emission: Vec3 = Vec3.zeros(),
    emission_strength: f32 = 0.0,
};

pub const Material = struct {
    allocator: std.mem.Allocator,

    label: []const u8,
    shader_id: UniqueIDType = UniqueID.INVALID,

    properties: MaterialProperties = .{},

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
