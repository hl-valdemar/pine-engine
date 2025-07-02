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

    // register systems
    try app.registerSystem(SetupSystem, .Init);
    try app.registerSystem(InputSystem, .Update);
    try app.registerSystem(UpdateClearColorSystem, .Update);

    // fire off the app
    try app.run();
}

/// This system is simply responsible for spawning a window on startup.
/// It'll be registered to run on the .Init schedule, meaning only once on initialization.
const SetupSystem = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) anyerror!SetupSystem {
        return SetupSystem{ .allocator = allocator };
    }

    pub fn deinit(_: *SetupSystem) void {}

    pub fn process(self: *SetupSystem, registry: *ecs.Registry) anyerror!void {
        // create the window component
        var window = try pine.WindowComponent.init(self.allocator, .{
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
/// It'll be registered to run on the .Update schedule, querying frame count on each update cycle.
const UpdateClearColorSystem = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) anyerror!UpdateClearColorSystem {
        return UpdateClearColorSystem{ .allocator = allocator };
    }

    pub fn deinit(_: *UpdateClearColorSystem) void {}

    pub fn process(self: *UpdateClearColorSystem, registry: *ecs.Registry) anyerror!void {
        // query just a single resource
        const frame_count = try registry.querySingleResource(self.allocator, pine.FrameCount);
        defer self.allocator.destroy(frame_count); // note: we must deallocate this copy manually

        // update the clear color accordingly for all render targets
        if (frame_count.*) |count| {
            var renderables = try registry.queryComponents(.{pine.RenderTargetComponent});
            while (renderables.next()) |entity| {
                const target = entity.get(pine.RenderTargetComponent).?;
                target.clear_color.r = @sin(@as(f32, @floatFromInt(count.value)) * 0.01) * 0.5 + 0.5;
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
/// It'll be registered to run on the .Update schedule, querying for system events and reacting accordingly.
const InputSystem = struct {
    allocator: Allocator,
    prng: std.Random.Xoshiro256,

    pub fn init(allocator: Allocator) anyerror!InputSystem {
        // get a secure random seed from the OS
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));

        return InputSystem{
            .allocator = allocator,
            // create a PRNG with the seed
            .prng = std.Random.DefaultPrng.init(seed),
        };
    }

    pub fn deinit(_: *InputSystem) void {}

    pub fn process(self: *InputSystem, registry: *ecs.Registry) anyerror!void {
        // get random values
        const rand = self.prng.random();

        // query for system events
        var events = try registry.queryResource(pine.WindowEvent);

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
                            var window = try pine.WindowComponent.init(self.allocator, .{
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
