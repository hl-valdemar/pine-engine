const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pw = @import("pine-window");

const event = @import("event.zig");
const Event = event.Event;
const Key = event.Key;
const KeyState = event.KeyState;
const Modifier = event.Modifier;
const log = @import("log.zig");
const Message = @import("message.zig").Message;
const Schedule = @import("schedule.zig").Schedule;

pub const WindowComponent = struct {
    handle: pw.Window,

    pub fn init(desc: pw.WindowConfig) !WindowComponent {
        const handle = try pw.Window.create(std.heap.page_allocator, desc);

        return WindowComponent{
            .handle = handle,
        };
    }

    // pub fn setTitle(self: *WindowComponent, title: [*c]const u8) void {
    //     c.glfwSetWindowTitle(self.handle, title);
    // }
    //
    // pub fn setPosition(self: *WindowComponent, x: c_int, y: c_int) void {
    //     c.glfwSetWindowPos(self.handle, x, y);
    // }
};

pub const WindowPlugin = ecs.Plugin.init("window", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        // initialize the windowing platform as a resource
        try registry.registerResource(pw.Platform);
        try registry.pushResource(try pw.Platform.init());

        // try registry.registerResource(pw.Event);

        try registry.registerTaggedSystem(EventPollingSystem, Schedule.PreUpdate.toString());
        try registry.registerTaggedSystem(WindowDestructionSystem, Schedule.PostUpdate.toString());
    }

    const EventPollingSystem = struct {
        allocator: Allocator,

        pub fn init(allocator: Allocator) anyerror!EventPollingSystem {
            return EventPollingSystem{
                .allocator = allocator,
            };
        }

        pub fn deinit(_: *EventPollingSystem) void {}

        pub fn process(self: *EventPollingSystem, registry: *ecs.Registry) anyerror!void {
            const platform_res = registry.querySingleResource(self.allocator, pw.Platform) catch return;
            defer self.allocator.destroy(platform_res);
            platform_res.*.?.pollEvents();

            var window_entities = registry.queryComponents(.{WindowComponent}) catch return;

            // loop through all windows and poll for events
            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;
                var num_closed: u32 = 0;
                if (window.handle.shouldClose() catch false) {
                    // destroy both the entity and the window resource
                    window.handle.destroy();
                    _ = try registry.destroyEntity(entity.id());

                    num_closed += 1;

                    if (num_closed == window_entities.views.len) {
                        try registry.pushResource(Message{ .shutdown = .requested });
                        window_entities.deinit(); // necessary as we don't reach the auto-deinit at the end of the iterator
                        break; // no need to continue
                    }
                }

                // handle window events
                while (try window.handle.pollEvent()) |ev| {
                    try registry.pushResource(Event{ .window_event = ev });
                }
            }
        }
    };

    // const EventPollingSystem = struct {
    //     const KeyInfo = struct {
    //         key: Key,
    //         window_id: WindowID,
    //     };
    //
    //     last_key_events: std.AutoHashMap(KeyInfo, KeyState),
    //
    //     pub fn init(allocator: std.mem.Allocator) anyerror!EventPollingSystem {
    //         return EventPollingSystem{
    //             .last_key_events = std.AutoHashMap(KeyInfo, KeyState).init(allocator),
    //         };
    //     }
    //
    //     pub fn deinit(self: *EventPollingSystem) void {
    //         self.last_key_events.deinit();
    //     }
    //
    //     pub fn process(self: *EventPollingSystem, registry: *ecs.Registry) anyerror!void {
    //         var window_entities = registry.queryComponents(.{WindowComponent}) catch return;
    //
    //         // loop through all windows and poll for events
    //         var num_closed: u32 = 0;
    //         while (window_entities.next()) |entity| {
    //             const window = entity.get(WindowComponent).?;
    //             if (c.glfwWindowShouldClose(window.handle) == c.GLFW_TRUE) {
    //                 num_closed += 1;
    //
    //                 // destroy and remove window from resources
    //                 c.glfwDestroyWindow(window.handle);
    //                 _ = try registry.destroyEntity(entity.id());
    //
    //                 if (num_closed == window_entities.views.len) {
    //                     try registry.pushResource(Message{ .Shutdown = .Requested });
    //                     window_entities.deinit(); // necessary as we don't reach the auto-deinit at the end of the iterator
    //                     break; // no need to continue
    //                 }
    //             }
    //
    //             try self.handleKeyEvents(window, registry);
    //
    //             c.glfwPollEvents();
    //         }
    //     }
    //
    //     fn handleKeyEvents(
    //         self: *EventPollingSystem,
    //         window: *WindowComponent,
    //         registry: *ecs.Registry,
    //     ) !void {
    //         // set modifier values
    //         var modifiers: Modifier.Type = Modifier.NONE;
    //         if (c.glfwGetKey(window.handle, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS or
    //             c.glfwGetKey(window.handle, c.GLFW_KEY_RIGHT_SHIFT) == c.GLFW_PRESS)
    //         {
    //             modifiers = modifiers | Modifier.SHIFT;
    //         }
    //
    //         // push key events
    //         for (std.enums.values(Key)) |key| {
    //             const glfw_key: c_int = @intFromEnum(key);
    //
    //             if (c.glfwGetKey(window.handle, glfw_key) == c.GLFW_PRESS) {
    //                 var ev = Event{
    //                     .keyEvent = .{
    //                         .key = key,
    //                         .state = .Pressed,
    //                         .window_id = window.id,
    //                         .modifiers = modifiers,
    //                     },
    //                 };
    //
    //                 const key_info = KeyInfo{ .key = key, .window_id = window.id };
    //                 if (self.last_key_events.get(key_info)) |state| {
    //                     if (state != .JustPressed and state != .Pressed) {
    //                         ev.keyEvent.state = .JustPressed;
    //                     }
    //                 }
    //                 try self.last_key_events.put(key_info, ev.keyEvent.state);
    //
    //                 try registry.pushResource(ev);
    //             }
    //
    //             if (c.glfwGetKey(window.handle, glfw_key) == c.GLFW_RELEASE) {
    //                 var ev = Event{ .keyEvent = .{
    //                     .key = key,
    //                     .state = .Released,
    //                     .window_id = window.id,
    //                     .modifiers = modifiers,
    //                 } };
    //
    //                 const key_info = KeyInfo{ .key = key, .window_id = window.id };
    //                 if (self.last_key_events.get(key_info)) |state| {
    //                     if (state != .JustReleased and state != .Released) {
    //                         ev.keyEvent.state = .JustReleased;
    //                     }
    //                 }
    //                 try self.last_key_events.put(key_info, ev.keyEvent.state);
    //
    //                 try registry.pushResource(ev);
    //             }
    //         }
    //     }
    // };

    const WindowDestructionSystem = struct {
        pub fn init(_: std.mem.Allocator) anyerror!WindowDestructionSystem {
            return WindowDestructionSystem{};
        }

        pub fn deinit(_: *WindowDestructionSystem) void {}

        pub fn process(_: *WindowDestructionSystem, registry: *ecs.Registry) anyerror!void {
            var messages = try registry.queryResource(Message);
            while (messages.next()) |message| {
                switch (message) {
                    .close_window => |window_id| {
                        log.debug("got window close event! {any}", .{message});
                        var window_entities = registry.queryComponents(.{WindowComponent}) catch return;
                        while (window_entities.next()) |entity| {
                            const window = entity.get(WindowComponent).?;
                            if (window.handle.id == window_id) {
                                log.debug("found window, closing (id = {d})!", .{message.close_window});
                                window.handle.requestClose();
                            }
                        }
                    },
                    else => {},
                }
            }
        }
    };
}.init);
