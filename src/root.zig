//-- global settings --//

pub const std_options = std.Options{
    .logFn = log.logFn,
};

//-- public exports --//

pub const log = @import("pine/log.zig");

// bundle pine-ecs with the pine engine
pub const ecs = @import("pecs");

pub const App = app.App;
pub const AppDesc = app.AppDesc;
pub const Event = event.Event;
pub const Key = event.Key;
pub const KeyState = event.KeyState;
pub const Modifier = event.Modifier;
pub const Message = message.Message;

pub const WindowResource = window.WindowResource;
pub const WindowPlugin = window.WindowPlugin;

//-- private imports --//

const std = @import("std");
const app = @import("pine/app.zig");
const window = @import("pine/window.zig");
const event = @import("pine/event.zig");
const message = @import("pine/message.zig");
