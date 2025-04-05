const std = @import("std");

const UniqueIDType = @import("../resource_manager.zig").UniqueIdDataType;
const Vec3 = @import("../math.zig").Vec3;
const Transform = @import("../transform.zig").Transform;
const Light = @import("light.zig").Light;
const LightTypeStruct = @import("light.zig").LightTypeStruct;

const LightEntry = struct {
    node_id: UniqueIDType,
    light: Light,
    transform: Transform,
};

pub const LightManager = struct {
    allocator: std.mem.Allocator,

    max_directional_lights: usize = 4,
    directional_lights: std.ArrayList(LightEntry),

    max_point_lights: usize = 4,
    point_lights: std.ArrayList(LightEntry),

    ambient_light: Vec3 = Vec3.with(0.1, 0.1, 0.1),

    pub fn init(allocator: std.mem.Allocator) LightManager {
        return LightManager{
            .allocator = allocator,
            .directional_lights = std.ArrayList(LightEntry).init(allocator),
            .point_lights = std.ArrayList(LightEntry).init(allocator),
        };
    }

    pub fn deinit(self: *const LightManager) void {
        self.directional_lights.deinit();
        self.point_lights.deinit();
    }

    pub fn addLightEntry(self: *LightManager, light_entry: LightEntry) !void {
        switch (light_entry.light.light_type) {
            .Directional => try self.directional_lights.append(light_entry),
            .Point => try self.point_lights.append(light_entry),
        }
    }
};
