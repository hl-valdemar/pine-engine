const std = @import("std");
const Allocator = std.mem.Allocator;

const pine = @import("pine-engine");
const ecs = pine.ecs;

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // initialize the app
    var app = try pine.App.init(allocator, .{});
    defer app.deinit();

    // add the window plugin
    try app.addPlugin(pine.WindowPlugin);
    try app.addPlugin(pine.RenderPlugin);
    try app.addPlugin(pine.TimingPlugin);

    // register systems
    try app.addSystem("startup", SetupSystem);
    try app.addSystem("update.main", InputSystem);
    try app.addSystem("update.main", UpdateClearColorSystem);

    // fire off the app
    try app.run();
}

/// This system is simply responsible for spawning a window on startup.
/// It'll be registered to run in the startup stage, meaning only once on initialization.
const SetupSystem = struct {
    pub fn process(_: *SetupSystem, registry: *ecs.Registry) anyerror!void {
        // create the window component
        var window = try pine.WindowComponent.init(.{
            .width = 500,
            .height = 500,
            .position = .{ .center = true },
            .title = "Pine Engine # Window Example",
        });

        // create the render target
        const render_target = try pine.RenderTargetComponent.init(&window.handle, .{
            .clear_color = .{ .r = 0.9, .g = 0.3, .b = 0.3, .a = 1.0 },
        });

        // spawn the window entity
        _ = try registry.spawn(.{ window, render_target });
    }
};

/// This system updates the clear color of the windows.
/// It'll be registered to run in the update's main stage, querying frame count on each update cycle.
const UpdateClearColorSystem = struct {
    pub fn process(_: *UpdateClearColorSystem, registry: *ecs.Registry) anyerror!void {
        const time_millis = switch (try registry.queryResource(pine.TimeMillis)) {
            .single => |time| time,
            .collection => unreachable,
        };

        // update the clear color accordingly for all render targets
        if (time_millis.resource) |millis| {
            var target_query = try registry.queryComponents(.{pine.RenderTargetComponent});
            defer target_query.deinit();

            while (target_query.next()) |entity| {
                const target = entity.get(pine.RenderTargetComponent).?;
                target.clear_color.r = @sin(@as(f32, @floatFromInt(millis.value)) * 0.01) * 0.5 + 0.5;
            }
        }

        // // log frame time
        // const frame_time = try registry.querySingleResource(self.allocator, pine.FrameTime);
        // defer self.allocator.destroy(frame_time);
        // if (frame_time.*) |dt| {
        //     std.log.debug("Frame time: {d}", .{dt.value});
        // }
    }
};

/// This system is responsible for handling key presses.
/// It'll be registered to run in the update's main stage, querying for system events and reacting accordingly.
const InputSystem = struct {
    prng: std.Random.Xoshiro256,

    pub fn init(_: Allocator) anyerror!InputSystem {
        // get a secure random seed from the OS
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));

        return InputSystem{
            // create a PRNG with the seed
            .prng = std.Random.DefaultPrng.init(seed),
        };
    }

    pub fn process(self: *InputSystem, registry: *ecs.Registry) anyerror!void {
        // get random values
        const rand = self.prng.random();

        // query for system events
        var events = switch (try registry.queryResource(pine.WindowEvent)) {
            .collection => |col| col,
            .single => unreachable,
        };
        defer events.deinit();

        // react accordingly
        while (events.next()) |event| {
            switch (event) {
                .key_up => |key_event| {
                    switch (key_event.key) {
                        .escape => if (key_event.mods.shift and !key_event.is_repeat) {
                            std.log.debug("shift+escape was 'just' released, shutting down! [{any}]", .{event});

                            // push the shutdown request to the registry
                            try registry.pushResource(pine.Message{ .shutdown = .requested });
                        } else if (!key_event.is_repeat) {
                            std.log.debug("escape was 'just' released, closing window! [{any}]", .{event});

                            // push a close window request to the registry
                            try registry.pushResource(pine.Message{
                                .close_window = event.key_up.window_id,
                            });
                        },
                        .enter => if (!event.key_up.is_repeat) {
                            std.log.debug("enter was 'just' released, spawning window! [{any}]", .{event});

                            // random width and height for endless fun
                            const width = rand.intRangeAtMost(u16, 250, 750);
                            const height = rand.intRangeAtMost(u16, 250, 750);

                            // why not make the position random as well
                            const x = rand.intRangeAtMost(u16, 250, 750);
                            const y = rand.intRangeAtMost(u16, 250, 750);

                            // create the window
                            var window = try pine.WindowComponent.init(.{
                                .width = width,
                                .height = height,
                                .position = .{ .x = x, .y = y },
                                .title = "Pine Engine # Window Example",
                            });

                            // create the render target
                            const render_target = try pine.RenderTargetComponent.init(&window.handle, .{
                                .clear_color = .{ .r = 0.9, .g = 0.3, .b = 0.3, .a = 1.0 },
                            });

                            // spawn the window as an entity to be managed by the ecs
                            _ = try registry.spawn(.{ window, render_target });
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }
};
