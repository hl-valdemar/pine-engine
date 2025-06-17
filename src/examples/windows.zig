const std = @import("std");
const Allocator = std.mem.Allocator;

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
/// It runs on the .Init schedule, meaning only once on initialization.
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

        // spawn the window
        _ = try registry.spawn(.{ window });
    }
};

/// This system is responsible for handling key presses.
/// It runs on the .Update schedule, querying for system events and reacting accordingly.
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
            switch (event.keyEvent.state) {
                .JustReleased => switch (event.keyEvent.key) {
                    .Escape => { // close the currently active window on escape
                        std.log.debug("escape was 'just' released, closing window! {any}", .{ event });

                        // escape + right shift -> stop the program
                        if (event.keyEvent.modifiers & pine.Modifier.RIGHT_SHIFT != 0) {
                            try registry.pushResource(pine.Message{
                                .Shutdown = .Requested,
                            });
                        } else { // just escape -> close active window
                            try registry.pushResource(pine.Message{
                                .CloseWindow = event.keyEvent.window_id,
                            });
                        }
                    },
                    .Enter => { // spawn a new window on enter
                        std.log.debug("enter was 'just' released, spawning window! {any}", .{ event });

                        // random width and height for endless fun
                        const width = rand.intRangeAtMost(u16, 250, 750);
                        const height = rand.intRangeAtMost(u16, 250, 750);

                        // create and push the window
                        const window = try pine.WindowComponent.init(.{
                            .width = width,
                            .height = height,
                            .title = "Pine Engine # Extra Window!",
                        });
                        _ = try registry.spawn(.{ window });
                    },
                },
                else => {}
            }
        }
    }
};
