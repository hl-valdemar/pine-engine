//-- global settings --//

pub const std_options = std.Options{
    .logFn = log.logFn,
};

//-- public exports --//

pub const log = @import("engine/log.zig");

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
const app = @import("engine/app.zig");
const message = @import("engine/message.zig");
const window = @import("engine/window.zig");
const renderer = @import("engine/renderer.zig");
