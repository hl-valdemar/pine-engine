// global settings //

pub const std_options = std.Options{
    .logFn = log.logFn,
};

// public exports //

pub const log = @import("engine/log.zig");

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
pub const WindowEvent = @import("engine/window.zig").WindowEvent;
pub const FrameCount = render.FrameCount;
pub const FrameTime = render.FrameTime;
pub const TimeNanos = time.TimeNanos;
pub const TimeMicros = time.TimeMicros;
pub const TimeMillis = time.TimeMillis;
pub const TimeSecs = time.TimeSecs;

// components
pub const component = struct {
    pub const Window = @import("engine/window.zig").WindowComponent;
    pub const RenderTarget = render.RenderTargetComponent;
    pub const TermPosition = term.TermPositionComponent;
    pub const TermSprite = term.TermSpriteComponent;
};

// plugins
pub const TimingPlugin = @import("engine/time.zig").TimingPlugin;
pub const WindowPlugin = @import("engine/window.zig").WindowPlugin;
pub const RenderPlugin = render.RenderPlugin;
pub const RenderTerminalPlugin = term.RenderTerminalPlugin;

// private imports //

const std = @import("std");
const app = @import("engine/app.zig");
const message = @import("engine/message.zig");
const render = @import("engine/render.zig");
const time = @import("engine/time.zig");
const term = @import("engine/terminal.zig");
