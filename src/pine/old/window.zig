const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");

const event = @import("event.zig");
const Event = event.Event;
const Key = event.Key;
const KeyState = event.KeyState;
const Modifier = event.Modifier;
const glfw = @import("wrapper/glfw.zig");
const c = glfw.c;
const log = @import("log.zig");
const Message = @import("message.zig").Message;
const Schedule = @import("schedule.zig").Schedule;

pub const WindowID = usize;

pub const WindowDesc = struct {
    width: c_int,
    height: c_int,
    title: [*c]const u8,
    position: ?struct { x: c_int, y: c_int } = null,
};

pub const WindowComponent = struct {
    var next_id: WindowID = 0;

    id: WindowID,
    handle: *c.GLFWwindow,

    pub fn init(desc: WindowDesc) !WindowComponent {
        // if (desc_def.no_depth_buffer) {
        //     glfwWindowHint(GLFW_DEPTH_BITS, 0);
        //     glfwWindowHint(GLFW_STENCIL_BITS, 0);
        // }

        // set opengl hints for compatibility
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

        // on macos, we need forward compatibility
        if (@import("builtin").os.tag == .macos) {
            c.glfwWindowHint(c.GLFW_COCOA_RETINA_FRAMEBUFFER, 0);
            c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GLFW_TRUE);
        }

        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

        // for multi-sampling (anti-aliasing)
        c.glfwWindowHint(c.GLFW_SAMPLES, 1);

        // enable v-sync (1 = on, 0 = off)
        c.glfwSwapInterval(1);

        const handle = c.glfwCreateWindow(desc.width, desc.height, desc.title, null, null) orelse
            return error.WindowCreationError;

        if (desc.position) |p| {
            c.glfwSetWindowPos(handle, p.x, p.y);
        }

        return WindowComponent{
            .id = nextId(),
            .handle = handle,
        };
    }

    pub fn setTitle(self: *WindowComponent, title: [*c]const u8) void {
        c.glfwSetWindowTitle(self.handle, title);
    }

    pub fn setPosition(self: *WindowComponent, x: c_int, y: c_int) void {
        c.glfwSetWindowPos(self.handle, x, y);
    }

    fn nextId() WindowID {
        defer next_id += 1;
        return next_id;
    }
};

pub const WindowPlugin = ecs.Plugin.init("window", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        try registry.registerTaggedSystem(GLFW_InitSystem, Schedule.Init.toString());
        try registry.registerTaggedSystem(EventPollingSystem, Schedule.PreUpdate.toString());
        try registry.registerTaggedSystem(WindowDestructionSystem, Schedule.PostUpdate.toString());
    }

    const GLFW_InitSystem = struct {
        pub fn init(_: Allocator) anyerror!GLFW_InitSystem {
            return GLFW_InitSystem{};
        }

        pub fn deinit(_: *GLFW_InitSystem) void {
            terminateGLFW();
        }

        pub fn process(_: *GLFW_InitSystem, _: *ecs.Registry) anyerror!void {
            try setupGLFW();
        }

        fn setupGLFW() !void {
            var major: i32 = 0;
            var minor: i32 = 0;
            var rev: i32 = 0;

            c.glfwGetVersion(&major, &minor, &rev);
            log.debug("using GLFW v{}.{}.{}", .{ major, minor, rev });

            if (c.glfwInit() == c.GLFW_FALSE)
                return error.GLFW_InitError;
        }

        fn terminateGLFW() void {
            log.debug("terminating GLFW...", .{});
            c.glfwTerminate();
        }
    };

    const EventPollingSystem = struct {
        const KeyInfo = struct {
            key: Key,
            window_id: WindowID,
        };

        last_key_events: std.AutoHashMap(KeyInfo, KeyState),

        pub fn init(allocator: std.mem.Allocator) anyerror!EventPollingSystem {
            return EventPollingSystem{
                .last_key_events = std.AutoHashMap(KeyInfo, KeyState).init(allocator),
            };
        }

        pub fn deinit(self: *EventPollingSystem) void {
            self.last_key_events.deinit();
        }

        pub fn process(self: *EventPollingSystem, registry: *ecs.Registry) anyerror!void {
            var window_entities = registry.queryComponents(.{WindowComponent}) catch return;

            // loop through all windows and poll for events
            var num_closed: u32 = 0;
            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;
                if (c.glfwWindowShouldClose(window.handle) == c.GLFW_TRUE) {
                    num_closed += 1;

                    // destroy and remove window from resources
                    c.glfwDestroyWindow(window.handle);
                    _ = try registry.destroyEntity(entity.id());

                    if (num_closed == window_entities.views.len) {
                        try registry.pushResource(Message{ .Shutdown = .Requested });
                        window_entities.deinit(); // necessary as we don't reach the auto-deinit at the end of the iterator
                        break; // no need to continue
                    }
                }

                try self.handleKeyEvents(window, registry);

                c.glfwPollEvents();
            }
        }

        fn handleKeyEvents(
            self: *EventPollingSystem,
            window: *WindowComponent,
            registry: *ecs.Registry,
        ) !void {
            // set modifier values
            var modifiers: Modifier.Type = Modifier.NONE;
            if (c.glfwGetKey(window.handle, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS or
                c.glfwGetKey(window.handle, c.GLFW_KEY_RIGHT_SHIFT) == c.GLFW_PRESS)
            {
                modifiers = modifiers | Modifier.SHIFT;
            }

            // push key events
            for (std.enums.values(Key)) |key| {
                const glfw_key: c_int = @intFromEnum(key);

                if (c.glfwGetKey(window.handle, glfw_key) == c.GLFW_PRESS) {
                    var ev = Event{
                        .keyEvent = .{
                            .key = key,
                            .state = .Pressed,
                            .window_id = window.id,
                            .modifiers = modifiers,
                        },
                    };

                    const key_info = KeyInfo{ .key = key, .window_id = window.id };
                    if (self.last_key_events.get(key_info)) |state| {
                        if (state != .JustPressed and state != .Pressed) {
                            ev.keyEvent.state = .JustPressed;
                        }
                    }
                    try self.last_key_events.put(key_info, ev.keyEvent.state);

                    try registry.pushResource(ev);
                }

                if (c.glfwGetKey(window.handle, glfw_key) == c.GLFW_RELEASE) {
                    var ev = Event{ .keyEvent = .{
                        .key = key,
                        .state = .Released,
                        .window_id = window.id,
                        .modifiers = modifiers,
                    } };

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

    const WindowDestructionSystem = struct {
        pub fn init(_: std.mem.Allocator) anyerror!WindowDestructionSystem {
            return WindowDestructionSystem{};
        }

        pub fn deinit(_: *WindowDestructionSystem) void {}

        pub fn process(_: *WindowDestructionSystem, registry: *ecs.Registry) anyerror!void {
            var messages = try registry.queryResource(Message);
            while (messages.next()) |message| {
                switch (message) {
                    .CloseWindow => |window_id| {
                        log.debug("got window close event! {any}", .{message});
                        var window_entities = registry.queryComponents(.{WindowComponent}) catch return;
                        while (window_entities.next()) |entity| {
                            const window = entity.get(WindowComponent).?;
                            if (window.id == window_id) {
                                log.debug("found window, closing (id = {d})!", .{message.CloseWindow});
                                c.glfwSetWindowShouldClose(window.handle, 1);
                            }
                        }
                    },
                    else => {},
                }
            }
        }
    };
}.init);
