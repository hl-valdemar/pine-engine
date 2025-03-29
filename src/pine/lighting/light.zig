const std = @import("std");
const plog = @import("../logging.zig").log;

const Vec3 = @import("../math.zig").Vec3;
const Transform = @import("../transform.zig").Transform;
const UniqueIDType = @import("../resource_manager.zig").UniqueIDType;
const ResourceManager = @import("../resource_manager.zig").ResourceManager;
const Renderer = @import("../renderer.zig").Renderer;

const scene = @import("../scene.zig");
const SceneVisitor = scene.SceneVisitor;
const SceneNode = scene.SceneNode;

pub const LightType = enum {
    Directional,
};

pub const LightProperties = extern struct {
    color: Vec3 align(16) = Vec3.ones(),
    intensity: f32 align(16) = 1,
};

pub const Light = struct {
    light_type: LightType,
    properties: LightProperties,

    pub fn init(
        light_type: LightType,
        color: Vec3,
        intensity: f32,
    ) Light {
        return .{
            .light_type = light_type,
            .properties = .{
                .color = color,
                .intensity = intensity,
            },
        };
    }

    pub fn initDirectional(
        direction: Vec3,
        color: Vec3,
        intensity: f32,
    ) Light {
        _ = direction;
        const light = Light.init(.Directional, color, intensity);
        // light.properties.direction = direction.norm();
        return light;
    }
};
