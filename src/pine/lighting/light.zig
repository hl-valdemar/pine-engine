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
    color: Vec3 align(32) = Vec3.ones(),
    intensity: f32 = 1.0,
};

pub const Light = struct {
    light_type: LightType,
    properties: LightProperties,

    // NOTE: just for directional light (properly a better way)
    direction: Vec3 = Vec3.up(),

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
        var light = Light.init(.Directional, color, intensity);
        light.direction = direction.norm();
        return light;
    }
};
