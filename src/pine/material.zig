const std = @import("std");

const ShaderPass = @import("shader.zig").ShaderPass;

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
    properties: MaterialProperties = .{},
    shader_passes: std.ArrayList(ShaderPass),

    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
    ) !Material {
        const label_copy = try allocator.dupe(u8, label);
        errdefer allocator.free(label_copy);

        return .{
            .allocator = allocator,
            .label = label_copy,
            .shader_passes = std.ArrayList(ShaderPass).init(allocator),
        };
    }

    pub fn addShaderPass(self: *Material, shader_pass: ShaderPass) !void {
        try self.shader_passes.append(shader_pass);
    }

    pub fn removeShaderPassByIdx(self: *Material, idx: usize) void {
        self.shader_passes.orderedRemove(idx); // preserve order, as opposed to using swapRemove
    }

    pub fn removeShaderPassByUID(self: *Material, uid: UniqueIDType) void {
        for (self.shader_passes.items, 0..) |shader_pass, i| {
            if (shader_pass.id == uid) {
                self.shader_passes.orderedRemove(i); // preserve order
            }
        }
    }

    pub fn deinit(self: *Material) void {
        self.shader_passes.deinit();
        self.allocator.free(self.label);
    }
};
