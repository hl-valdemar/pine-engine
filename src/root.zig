//-- global settings --//

pub const std_options = std.Options{
    .logFn = log.logFn,
};

//-- public exports --//

pub const log = @import("pine/log.zig");

// bundle pine-ecs with the pine engine
pub const ecs = @import("pine-ecs");

pub const App = app.App;
pub const AppDesc = app.AppDesc;
pub const Message = message.Message;

pub const WindowComponent = window.WindowComponent;
pub const WindowPlugin = window.WindowPlugin;
pub const WindowEvent = @import("pine-window").Event;

pub const RenderPlugin = renderer.RenderPlugin;

//-- private imports --//

const std = @import("std");
const app = @import("pine/app.zig");
const message = @import("pine/message.zig");
const window = @import("pine/window.zig");
const renderer = @import("pine/renderer.zig");
