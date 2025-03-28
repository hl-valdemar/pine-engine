const std = @import("std");
const plog = @import("logging.zig").log;

const Vec3 = @import("math.zig").Vec3;
const Transform = @import("transform.zig").Transform;
const UniqueIDType = @import("resource_manager.zig").UniqueIDType;
const ResourceManager = @import("resource_manager.zig").ResourceManager;
const Renderer = @import("renderer.zig").Renderer;

const scene = @import("scene.zig");
const SceneVisitor = scene.SceneVisitor;
const SceneNode = scene.SceneNode;

pub const LightType = enum {
    Directional,
};

pub const Light = struct {
    light_type: LightType,
    color: Vec3,
    intensity: f32,

    direction: Vec3 = Vec3.up(),

    pub fn init(
        light_type: LightType,
        color: Vec3,
        intensity: f32,
    ) Light {
        return .{
            .light_type = light_type,
            .color = color,
            .intensity = intensity,
        };
    }

    pub fn initDirectional(
        direction: Vec3,
        color: Vec3,
        intensity: f32,
    ) Light {
        var light = Light.init(.Directional, color, intensity);
        light.direction = direction.norm();
        return light;
    }
};

const LightEntry = struct {
    node_id: UniqueIDType,
    light: Light,
    transform: Transform,
};

pub const LightManager = struct {
    allocator: std.mem.Allocator,

    directional_lights: std.ArrayList(LightEntry),

    ambient_light: Vec3 = Vec3.with(0.1, 0.1, 0.1),

    max_directional_lights: usize = 4,

    pub fn init(allocator: std.mem.Allocator) LightManager {
        return .{
            .allocator = allocator,
            .directional_lights = std.ArrayList(LightEntry).init(allocator),
        };
    }

    pub fn deinit(self: *const LightManager) void {
        self.directional_lights.deinit();
    }
};

pub const LightCollector = struct {
    visitor: SceneVisitor,
    renderer: *Renderer,
    resource_manager: *ResourceManager,

    pub fn init(renderer: *Renderer, resource_manager: *ResourceManager) LightCollector {
        return .{
            .visitor = SceneVisitor.init(LightCollector),
            .renderer = renderer,
            .resource_manager = resource_manager,
        };
    }

    pub fn visitNode(self: *LightCollector, node: *SceneNode) void {
        if (node.light) |light| {
            const world_transform = node.getWorldTransform();
            switch (light.light_type) {
                .Directional => {
                    // transform direction by world rotation
                    const world_dir = world_transform.rotation.rotateVec3(light.direction);

                    var dir_light = light;
                    dir_light.direction = world_dir;

                    self.renderer.light_manager.directional_lights.append(.{
                        .node_id = node.id,
                        .light = dir_light,
                        .transform = world_transform,
                    }) catch |err| {
                        plog.err("failed to add directional light: {}", .{err});
                    };
                },
            }
        }
    }
};
