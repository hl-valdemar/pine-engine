// global settings //
const std = @import("std");

pub const std_options = std.Options{
    .logFn = log.logFn,
};

// public exports //

pub const app = @import("app.zig");
pub const log = @import("log.zig");

// private imports //
