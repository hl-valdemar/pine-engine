const std = @import("std");
const plog = @import("../logging.zig").log;

const Vec3 = @import("../math.zig").Vec3;
const Transform = @import("../transform.zig").Transform;
const Renderer = @import("../renderer.zig").Renderer;

const resource_manager = @import("../resource_manager.zig");
const UniqueIDType = resource_manager.UniqueIdDataType;
const ResourceManager = resource_manager.ResourceManager;

const scene = @import("../scene.zig");
const SceneVisitor = scene.SceneVisitor;
const SceneNode = scene.SceneNode;

pub const LightType = enum(u32) {
    Directional = 0,
    Point = 1,
};

// NOTE: make sure that alignment follows the MSL specification
pub const LightProperties = extern struct {
    position: Vec3 align(16) = Vec3.with(0, 0, 0),
    direction: Vec3 align(16) = Vec3.with(0, 0, 0),
    color: Vec3 align(16) = Vec3.ones(),
    intensity: f32 align(8) = 1,
    is_active: bool align(1) = false,
};

pub const Light = struct {
    light_type: LightType,
    properties: LightProperties,

    fn init(light_type: LightType, color: Vec3, intensity: f32) Light {
        return Light{
            .light_type = light_type,
            .properties = .{
                .color = color,
                .intensity = intensity,
                .is_active = true,
            },
        };
    }

    pub fn initDirectional(direction: Vec3, color: Vec3, intensity: f32) Light {
        var light = Light.init(.Directional, color, intensity);
        light.properties.direction = direction.norm();
        return light;
    }

    pub fn initPoint(color: Vec3, intensity: f32) Light {
        return Light.init(.Point, color, intensity);
    }
};
