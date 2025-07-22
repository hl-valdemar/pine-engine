const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pw = @import("pine-window");
const pg = @import("pine-graphics");

const log = @import("log.zig");
const Message = @import("message.zig").Message;
const Schedule = @import("schedule.zig").Schedule;

const renderer = @import("renderer.zig");
const RenderPlugin = renderer.RenderPlugin;

// global window platform object
var g_platform: pw.Platform = undefined;

pub const WindowEvent = pw.Event;

pub const WindowComponent = struct {
    handle: pw.Window,

    pub fn init(desc: pw.WindowDesc) !WindowComponent {
        const handle = try pw.Window.create(&g_platform, desc);

        return WindowComponent{
            .handle = handle,
        };
    }
};

pub const WindowPlugin = ecs.Plugin.init("window", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        // initialize static platform
        g_platform = try pw.Platform.init();

        // register the window event
        try registry.registerResource(WindowEvent);

        // add window systems to appropriate substages
        if (registry.pipeline.getStage("update")) |update_stage| {
            if (update_stage.substages) |*substages| {
                try substages.addSystem("pre", EventPollingSystem);
                try substages.addSystem("main", WindowDestructionSystem);
            }
        }

        try registry.pipeline.addSystem("cleanup", CleanupSystem);
    }

    const EventPollingSystem = struct {
        allocator: Allocator,

        pub fn init(allocator: Allocator) anyerror!EventPollingSystem {
            return EventPollingSystem{
                .allocator = allocator,
            };
        }

        pub fn deinit(_: *EventPollingSystem) void {}

        pub fn process(_: *EventPollingSystem, registry: *ecs.Registry) anyerror!void {
            // if no poll, might as well be mole
            g_platform.pollEvents();

            var window_entities = registry.queryComponents(.{WindowComponent}) catch return;
            defer window_entities.deinit();

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
        pub fn init(_: Allocator) anyerror!WindowDestructionSystem {
            return WindowDestructionSystem{};
        }

        pub fn deinit(_: *WindowDestructionSystem) void {}

        pub fn process(_: *WindowDestructionSystem, registry: *ecs.Registry) anyerror!void {
            var messages = try registry.queryResource(Message);
            defer messages.deinit();

            while (messages.next()) |message| {
                switch (message) {
                    .close_window => |window_id| {
                        log.debug("got window close event! {any}", .{message});

                        var window_entities = registry.queryComponents(.{WindowComponent}) catch return;
                        defer window_entities.deinit();

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
        pub fn init(_: Allocator) anyerror!CleanupSystem {
            return CleanupSystem{};
        }

        pub fn deinit(_: *CleanupSystem) void {}

        pub fn process(_: *CleanupSystem, registry: *ecs.Registry) anyerror!void {
            // destroy all windows
            var window_entities = try registry.queryComponents(.{WindowComponent});
            defer window_entities.deinit();

            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;
                window.handle.destroy();
            }

            // destroy global window platform
            g_platform.deinit();
        }
    };
}.init);
