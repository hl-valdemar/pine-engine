const std = @import("std");

//-- public --//

pub const ResourceManager = resource_manager.ResourceManager;
pub const Renderer = renderer.Renderer;

pub const UniformType = material.UniformType;
pub const UniformData = material.UniformData;

pub const logging = @import("pine/logging.zig");
pub const math = @import("pine/math.zig");

//-- private --//

const resource_manager = @import("pine/resource_manager.zig");
const renderer = @import("pine/renderer.zig");
const material = @import("pine/material.zig");

test {
    std.testing.refAllDecls(math);
}
