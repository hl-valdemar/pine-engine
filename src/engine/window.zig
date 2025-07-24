const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pw = @import("pine-window");
const pg = @import("pine-graphics");

const log = @import("log.zig");
const Message = @import("message.zig").Message;

const renderer = @import("render/graphical.zig");
const RenderPlugin = renderer.RenderPlugin;

// global window platform object
// FIXME: should probably be converted to an optional
var g_platform: pw.Platform = undefined;

pub const WindowEvent = pw.Event;

pub const WindowComponent = struct {
    handle: pw.Window,

    pub fn init(desc: pw.WindowDesc) !WindowComponent {
        return WindowComponent{
            .handle = try pw.Window.init(&g_platform, desc),
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
        try registry.addSystem("update.pre", EventPollingSystem);
        try registry.addSystem("update.post", WindowDestructionSystem);
        try registry.addSystem("cleanup", CleanupSystem);
    }

    const EventPollingSystem = struct {
        pub fn process(_: *EventPollingSystem, registry: *ecs.Registry) anyerror!void {
            // remember to poll events!
            g_platform.pollEvents();

            var window_query = registry.queryComponents(.{WindowComponent}) catch return;
            defer window_query.deinit();

            // loop through all windows and poll for events
            while (window_query.next()) |entity| {
                const window = entity.get(WindowComponent).?;
                var num_closed: u32 = 0;
                if (window.handle.shouldClose() catch false) {
                    // destroy both the entity and the window resource
                    window.handle.deinit();
                    _ = try registry.destroyEntity(entity.id());

                    num_closed += 1;

                    if (num_closed == window_query.views.len) {
                        try registry.pushResource(Message{ .shutdown = .requested });
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
        pub fn process(_: *WindowDestructionSystem, registry: *ecs.Registry) anyerror!void {
            var message_query = try registry.queryResource(Message);
            defer message_query.deinit();

            while (message_query.next()) |message| {
                switch (message) {
                    .close_window => |window_id| {
                        log.debug("got window close event! {any}", .{message});

                        var window_query = registry.queryComponents(.{WindowComponent}) catch return;
                        defer window_query.deinit();

                        while (window_query.next()) |entity| {
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
        pub fn process(_: *CleanupSystem, registry: *ecs.Registry) anyerror!void {
            // destroy all windows
            var window_query = try registry.queryComponents(.{WindowComponent});
            defer window_query.deinit();

            while (window_query.next()) |entity| {
                const window = entity.get(WindowComponent).?;
                window.handle.deinit();
            }

            // destroy global window platform
            g_platform.deinit();
        }
    };
}.init);
