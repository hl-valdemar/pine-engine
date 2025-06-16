const pecs = @import("pecs");
const glfw = @import("glfw");
const log = @import("log.zig");

const std = @import("std");
const Allocator = std.mem.Allocator;

const Schedule = @import("schedule.zig").Schedule;
const Message = @import("message.zig").Message;

const event = @import("event.zig");
const Event = event.Event;
const Key = event.Key;
const KeyState = event.KeyState;
const Modifier = event.Modifier;

pub const WindowID = usize;

pub const WindowDesc = struct {
    width: c_int,
    height: c_int,
    title: [*:0]const u8,
};

pub const WindowResource = struct {
    var next_id: WindowID = 0;

    id: WindowID,
    handle: *glfw.Window,

    pub fn init(desc: WindowDesc) !WindowResource {
        return WindowResource{
            .id = nextId(),
            .handle = try glfw.createWindow(desc.width, desc.height, desc.title, null, null),
        };
    }

    fn nextId() WindowID {
        defer next_id += 1;
        return next_id;
    }
};

pub const WindowPlugin = pecs.Plugin.init("window", struct {
    fn init(registry: *pecs.Registry) !void {
        try registry.registerResource(WindowResource);

        try registry.registerTaggedSystem(InitWindowHandlerSystem, Schedule.Init.toString());
        try registry.registerTaggedSystem(DeinitWindowHandlerSystem, Schedule.Deinit.toString());
        try registry.registerTaggedSystem(PollEventsSystem, Schedule.PreUpdate.toString());
        try registry.registerTaggedSystem(DestroyWindowSystem, Schedule.PostUpdate.toString());
    }

    const InitWindowHandlerSystem = struct {
        allocator: Allocator,

        pub fn init(allocator: Allocator) anyerror!InitWindowHandlerSystem {
            return InitWindowHandlerSystem{
                .allocator = allocator,
            };
        }

        pub fn deinit(_: *InitWindowHandlerSystem) void {}

        pub fn process(_: *InitWindowHandlerSystem, _: *pecs.Registry) anyerror!void {
            try setupGLFW();
        }

        fn setupGLFW() !void {
            var major: i32 = 0;
            var minor: i32 = 0;
            var rev: i32 = 0;

            glfw.getVersion(&major, &minor, &rev);
            log.debug("using GLFW v{}.{}.{}", .{ major, minor, rev });

            try glfw.init();
        }
    };

    const DeinitWindowHandlerSystem = struct {
        pub fn init(_: Allocator) anyerror!DeinitWindowHandlerSystem {
            return DeinitWindowHandlerSystem{};
        }

        pub fn deinit(_: *DeinitWindowHandlerSystem) void {}

        pub fn process(_: *DeinitWindowHandlerSystem, _: *pecs.Registry) anyerror!void {
            terminateGLFW();
        }

        fn terminateGLFW() void {
            log.debug("terminating GLFW...", .{});
            glfw.terminate();
        }
    };

    const PollEventsSystem = struct {
        const KeyInfo = struct {
            key: Key,
            window_id: WindowID,
        };

        last_key_events: std.AutoHashMap(KeyInfo, KeyState),

        pub fn init(allocator: std.mem.Allocator) anyerror!PollEventsSystem {
            return PollEventsSystem{
                .last_key_events = std.AutoHashMap(KeyInfo, KeyState).init(allocator),
            };
        }

        pub fn deinit(self: *PollEventsSystem) void {
            self.last_key_events.deinit();
        }

        pub fn process(self: *PollEventsSystem, registry: *pecs.Registry) anyerror!void {
            const windows = registry.queryResource(WindowResource) catch return;

            if (windows.resources.len == 0)
                return;

            // loop through all windows (backwards!) and poll for events
            // note: we loop backwards to avoid problems with indeces on window destruction
            var num_closed: usize = 0;
            var idx: i32 = @intCast(windows.resources.len - 1); // length must be greater than 0!
            while (idx >= 0) : (idx -= 1) {
                const i: usize = @intCast(idx);
                const window = windows.resources[i];

                if (glfw.windowShouldClose(window.handle)) {
                    num_closed += 1;

                    // destroy and remove window from resources
                    glfw.destroyWindow(window.handle);
                    try registry.removeResource(WindowResource, i);

                    if (num_closed == windows.resources.len) {
                        try registry.pushResource(Message{ .Shutdown = .Requested });
                        break; // no need to continue
                    }
                }

                try self.handleKeyEvents(&window, registry);

                glfw.pollEvents();
            }
        }

        fn handleKeyEvents(self: *PollEventsSystem, window: *const WindowResource, registry: *pecs.Registry) !void {
            // set modifier values
            var modifiers: Modifier.Type = 0;
            if (glfw.getKey(window.handle, glfw.KeyLeftShift) == glfw.Press) {
                modifiers = modifiers | Modifier.LEFT_SHIFT;
            }
            if (glfw.getKey(window.handle, glfw.KeyRightShift) == glfw.Press) {
                modifiers = modifiers | Modifier.RIGHT_SHIFT;
            }

            // push key events
            for (std.enums.values(Key)) |key| {
                const glfw_key = switch (key) {
                    .Escape => glfw.KeyEscape,
                    .Enter => glfw.KeyEnter,
                };

                if (glfw.getKey(window.handle, glfw_key) == glfw.Press) {
                    var ev = Event{.keyEvent = .{
                        .key = key,
                        .state = .Pressed,
                        .window_id = window.id,
                        .modifiers = modifiers,
                    }};

                    const key_info = KeyInfo{ .key = key, .window_id = window.id };
                    if (self.last_key_events.get(key_info)) |state| {
                        if (state != .JustPressed and state != .Pressed) {
                            ev.keyEvent.state = .JustPressed;
                        }
                    }
                    try self.last_key_events.put(key_info, ev.keyEvent.state);

                    try registry.pushResource(ev);
                }

                if (glfw.getKey(window.handle, glfw_key) == glfw.Release) {
                    var ev = Event{.keyEvent = .{
                        .key = key,
                        .state = .Released,
                        .window_id = window.id,
                        .modifiers = modifiers,
                    }};

                    const key_info = KeyInfo{ .key = key, .window_id = window.id };
                    if (self.last_key_events.get(key_info)) |state| {
                        if (state != .JustReleased and state != .Released) {
                            ev.keyEvent.state = .JustReleased;
                        }
                    }
                    try self.last_key_events.put(key_info, ev.keyEvent.state);

                    try registry.pushResource(ev);
                }
            }
        }
    };

    const DestroyWindowSystem = struct {
        pub fn init(_: std.mem.Allocator) anyerror!DestroyWindowSystem {
            return DestroyWindowSystem{};
        }

        pub fn deinit(_: *DestroyWindowSystem) void {}

        pub fn process(_: *DestroyWindowSystem, registry: *pecs.Registry) anyerror!void {
            var messages = try registry.queryResource(Message);
            while (messages.next()) |message| {
                switch (message.*) {
                    .CloseWindow => |window_id| {
                        log.debug("got window close event! {any}", .{ message });
                        var windows = registry.queryResource(WindowResource) catch unreachable;
                        while (windows.next()) |window| {
                            if (window.id == window_id) {
                                log.debug("found window, closing (id = {d})!", .{ message.CloseWindow });
                                glfw.setWindowShouldClose(window.handle, true);
                            }
                        }
                    },
                    else => {}
                }
            }
        }
    };
}.init);
