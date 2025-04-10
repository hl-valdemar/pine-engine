//-- public --//

pub const ResourceManager = resource_manager.ResourceManager;
pub const Renderer = renderer.Renderer;
pub const Camera = camera.Camera;
pub const Scene = scene.Scene;
pub const UniqueIDType = resource_manager.UniqueIdDataType;
pub const UniqueID = resource_manager.UniqueId;
pub const Light = light.Light;
pub const ShaderPass = shader.ShaderPass;

pub const logging = @import("pine/logging.zig");
pub const math = @import("pine/math.zig");
pub const material = @import("pine/material.zig");
pub const transform = @import("pine/transform.zig");
pub const perlin = @import("pine/perlin.zig");
pub const primitive = @import("pine/primitive/primitive.zig");

//-- private --//

const resource_manager = @import("pine/resource_manager.zig");
const renderer = @import("pine/renderer.zig");
const camera = @import("pine/camera.zig");
const scene = @import("pine/scene.zig");
const light = @import("pine/lighting/light.zig");
const shader = @import("pine/shader.zig");

//-- testing --//

const std = @import("std");

test {
    std.testing.refAllDecls(math);
}
