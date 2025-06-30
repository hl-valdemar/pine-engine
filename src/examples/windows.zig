const std = @import("std");
const Allocator = std.mem.Allocator;

const pine = @import("pine-engine");
const ecs = pine.ecs;
const pg = pine.graphics;

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // initialize the app
    var app = try pine.App.init(allocator, .{});
    defer app.deinit();

    // add the window plugin
    try app.addPlugin(pine.WindowPlugin);
    try app.addPlugin(pine.RenderPlugin);

    // register systems
    try app.registerSystem(SetupSystem, .Init);
    try app.registerSystem(InputSystem, .Update);

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
        var window = try pine.WindowComponent.init(
            self.allocator,
            .{
                .width = 500,
                .height = 500,
                .position = .{ .center = true },
                .title = "Pine Engine # Window Example",
            },
        );

        var graphics_ctx = try pg.GraphicsContext.create(.auto);

        // query and log graphics capabilities
        const caps = graphics_ctx.getCapabilities();
        std.log.info("graphics backend capabilities:", .{});
        std.log.info("  - compute shaders: {}", .{caps.compute_shaders});
        std.log.info("  - tessellation: {}", .{caps.tessellation});
        std.log.info("  - max texture size: {}", .{caps.max_texture_size});

        const swapchain = try pg.Swapchain.create(&graphics_ctx, &window.handle);

        const render_target = pine.renderer.RenderTarget{
            .context = graphics_ctx,
            .swapchain = swapchain,
        };

        // spawn the window entity
        _ = try registry.spawn(.{ window, render_target });
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
                .key_up => {
                    switch (event.key_up.key) {
                        .escape => {
                            if (event.key_up.mods.shift) {
                                std.log.debug("shift+escape was 'just' released, shutting down! [{any}]", .{event});
                                try registry.pushResource(pine.Message{ .shutdown = .requested });
                            } else if (!event.key_up.is_repeat) { // just escape -> close active window
                                std.log.debug("escape was 'just' released, closing window! [{any}]", .{event});
                                try registry.pushResource(pine.Message{
                                    .close_window = event.key_up.window_id,
                                });
                            }
                        },
                        .enter => { // spawn a new window on enter
                            if (!event.key_up.is_repeat) {
                                std.log.debug("enter was 'just' released, spawning window! [{any}]", .{event});

                                // random width and height for endless fun
                                const width = rand.intRangeAtMost(u16, 250, 750);
                                const height = rand.intRangeAtMost(u16, 250, 750);

                                const x = rand.intRangeAtMost(u16, 250, 750);
                                const y = rand.intRangeAtMost(u16, 250, 750);

                                // create the window
                                const window = try pine.WindowComponent.init(
                                    self.allocator,
                                    .{
                                        .width = width,
                                        .height = height,
                                        .position = .{ .x = x, .y = y },
                                        .title = "Pine Engine # Window Example",
                                    },
                                );

                                // spawn the window as an entity to be managed by the ecs
                                _ = try registry.spawn(.{window});
                            }
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }
};
