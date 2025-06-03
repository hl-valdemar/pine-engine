// global settings //
const std = @import("std");

pub const std_options = std.Options{
    .logFn = log.logFn,
};

// public exports //

// bundle pine-ecs with the pine engine
pub const ecs = @import("pecs");

pub const app = @import("pine/app.zig");
pub const log = @import("pine/log.zig");

// private imports //
