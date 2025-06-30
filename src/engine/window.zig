const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pw = @import("pine-window");
const pg = @import("pine-graphics");

const log = @import("log.zig");
const Message = @import("message.zig").Message;
const Schedule = @import("schedule.zig").Schedule;
const RenderPlugin = @import("renderer.zig").RenderPlugin;

pub const WindowEvent = pw.Event;

pub const WindowComponent = struct {
    handle: pw.Window,

    pub fn init(allocator: Allocator, desc: pw.WindowDesc) !WindowComponent {
        const handle = try pw.Window.create(allocator, desc);

        return WindowComponent{
            .handle = handle,
        };
    }
};

pub const WindowPlugin = ecs.Plugin.init("window", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        // initialize the windowing platform as a resource
        try registry.registerResource(pw.Platform);
        try registry.pushResource(try pw.Platform.init());

        // register the window event
        try registry.registerResource(WindowEvent);

        // register window-related systems
        try registry.registerTaggedSystem(EventPollingSystem, Schedule.PreUpdate.toString());
        try registry.registerTaggedSystem(WindowDestructionSystem, Schedule.PostUpdate.toString());
        try registry.registerTaggedSystem(CleanupSystem, Schedule.Deinit.toString());

        // add the render plugin
        try registry.addPlugin(RenderPlugin);
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
                    registry.pushResource(ev) catch unreachable; // the window event must be registered!
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

    const CleanupSystem = struct {
        pub fn init(_: std.mem.Allocator) anyerror!CleanupSystem {
            return CleanupSystem{};
        }

        pub fn deinit(_: *CleanupSystem) void {}

        pub fn process(_: *CleanupSystem, registry: *ecs.Registry) anyerror!void {
            var window_entities = try registry.queryComponents(.{WindowComponent});
            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;
                window.handle.destroy();
            }
            // FIX: maybe we should also destroy the corresponding swapchains?
        }
    };
}.init);
