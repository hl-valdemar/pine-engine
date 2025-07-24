// global settings //

pub const std_options = std.Options{
    .logFn = log.logFn,
};

// public exports //

pub const log = @import("engine/log.zig");

// bundle pine modules with the pine engine
pub const ecs = @import("pine-ecs");
pub const graphics = @import("pine-graphics");
pub const window = @import("pine-window");

pub const App = app.App;
pub const AppDesc = app.AppDesc;
pub const Message = message.Message;
pub const Color = render.graphical.Color;

// resources
pub const WindowEvent = @import("engine/window.zig").WindowEvent;
pub const FrameCount = render.graphical.FrameCount;
pub const FrameTime = render.graphical.FrameTime;

// components
pub const WindowComponent = @import("engine/window.zig").WindowComponent;
pub const RenderTargetComponent = render.graphical.RenderTargetComponent;

// plugins
pub const WindowPlugin = @import("engine/window.zig").WindowPlugin;
pub const RenderPlugin = render.graphical.RenderPlugin;
pub const RenderTerminalPlugin = render.terminal.RenderTerminalPlugin;

// private imports //

const std = @import("std");
const app = @import("engine/app.zig");
const message = @import("engine/message.zig");
const render = @import("engine/render/render.zig");
