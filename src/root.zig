// global settings //

pub const std_options = std.Options{
    .logFn = log.logFn,
};

// public exports //

pub const log = @import("log.zig");

// bundle pine modules with the pine engine
pub const ecs = @import("pine-ecs");
pub const graphics = @import("pine-graphics");
pub const terminal = @import("pine-terminal");
pub const window = @import("pine-window");

pub const App = app.App;
pub const AppDesc = app.AppDesc;
pub const Message = message.Message;
pub const Color = render.Color;

// resources
pub const WindowEvent = @import("window.zig").WindowEvent;
pub const FrameCount = render.FrameCount;
pub const FrameTime = render.FrameTime;
pub const TimeNanos = time.TimeNanos;
pub const TimeMicros = time.TimeMicros;
pub const TimeMillis = time.TimeMillis;
pub const TimeSecs = time.TimeSecs;

// components
pub const component = struct {
    pub const Window = @import("window.zig").WindowComponent;
    pub const RenderTarget = render.RenderTargetComponent;
    pub const TermPosition = term.TermPositionComponent;
    pub const TermSprite = term.TermSpriteComponent;
};

// plugins
pub const TimingPlugin = @import("time.zig").TimingPlugin;
pub const WindowPlugin = @import("window.zig").WindowPlugin;
pub const RenderPlugin = render.RenderPlugin;
pub const RenderTerminalPlugin = term.RenderTerminalPlugin;

// private imports //

const std = @import("std");
const app = @import("app.zig");
const message = @import("message.zig");
const render = @import("render.zig");
const time = @import("time.zig");
const term = @import("terminal.zig");
