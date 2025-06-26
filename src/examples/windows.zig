const std = @import("std");
const Allocator = std.mem.Allocator;

// const glfw = @import("glfw");
const c = @cImport(@cInclude("GLFW/glfw3.h"));
const pine = @import("pine");
const pecs = pine.ecs;

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

    // register systems
    try app.registerSystem(SetupSystem, .Init);
    try app.registerSystem(InputSystem, .Update);

    // fire off the app
    try app.run();
}

/// This system is simply responsible for spawning a window on startup.
/// It'll be registered to run on the .Init schedule, meaning only once on initialization.
const SetupSystem = struct {
    pub fn init(_: Allocator) anyerror!SetupSystem {
        return SetupSystem{};
    }

    pub fn deinit(_: *SetupSystem) void {}

    pub fn process(_: *SetupSystem, registry: *pine.ecs.Registry) anyerror!void {
        // create the window component
        const window = try pine.WindowComponent.init(.{
            .width = 500,
            .height = 500,
            .title = "Pine Engine # Window Example",
        });

        // spawn the window entity
        _ = try registry.spawn(.{window});
    }
};

/// This system is responsible for handling key presses.
/// It'll be registered to run on the .Update schedule, querying for system events and reacting accordingly.
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

    pub fn deinit(_: *InputSystem) void {}

    pub fn process(self: *InputSystem, registry: *pecs.Registry) anyerror!void {
        // get random values
        const rand = self.prng.random();

        // query for system events
        var events = try registry.queryResource(pine.Event);

        // react accordingly
        while (events.next()) |event| {
            if (event.keyEvent.state == .JustReleased) {
                switch (event.keyEvent.key) {
                    .Escape => {
                        // escape + right shift -> stop the program
                        if (event.keyEvent.modifiers & pine.Modifier.SHIFT != 0) {
                            std.log.debug("shift+escape was 'just' released, shutting down! [{any}]", .{event});
                            try registry.pushResource(pine.Message{
                                .Shutdown = .Requested,
                            });
                        } else { // just escape -> close active window
                            std.log.debug("escape was 'just' released, closing window! [{any}]", .{event});
                            try registry.pushResource(pine.Message{
                                .CloseWindow = event.keyEvent.window_id,
                            });
                        }
                    },
                    .Enter => { // spawn a new window on enter
                        std.log.debug("enter was 'just' released, spawning window! [{any}]", .{event});

                        // random width and height for endless fun
                        const width, const height = computeWindowSize(rand);

                        // random position
                        const x, const y = computeWindowPosition(rand);

                        // create the window
                        var window = try pine.WindowComponent.init(.{
                            .width = width,
                            .height = height,
                            .title = "This will not be visible for long!",
                            .position = .{ .x = x, .y = y },
                        });

                        // the window component comes with some utility functions for setting certain traits
                        window.setTitle("Pine Engine # Extra Window!");

                        // spawn the window as an entity to be managed by the ecs
                        _ = try registry.spawn(.{window});
                    },
                    else => {},
                }
            }
        }
    }
};

// utility function, just ignore
fn computeWindowSize(rand: std.Random) struct { u16, u16 } {
    const width = rand.intRangeAtMost(u16, 250, 750);
    const height = rand.intRangeAtMost(u16, 250, 750);
    return .{ width, height };
}

// utility function, just ignore
fn computeWindowPosition(rand: std.Random) struct { u16, u16 } {
    // const monitor = glfw.getPrimaryMonitor();
    const monitor = c.glfwGetPrimaryMonitor();

    var width_physical: c_int = undefined;
    var height_physical: c_int = undefined;
    // glfw.getMonitorPhysicalSize(monitor, &width_physical, &height_physical);
    c.glfwGetMonitorPhysicalSize(monitor, &width_physical, &height_physical);

    var x_scale: f32 = undefined;
    var y_scale: f32 = undefined;
    // glfw.getMonitorContentScale(monitor, &x_scale, &y_scale);
    c.glfwGetMonitorContentScale(monitor, &x_scale, &y_scale);

    const width_logical: u16 = @intFromFloat(@as(f32, @floatFromInt(width_physical)) * x_scale);
    const height_logical: u16 = @intFromFloat(@as(f32, @floatFromInt(height_physical)) * y_scale);

    const x = rand.intRangeAtMost(u16, 0, width_logical);
    const y = rand.intRangeAtMost(u16, 0, height_logical);

    return .{ x, y };
}
