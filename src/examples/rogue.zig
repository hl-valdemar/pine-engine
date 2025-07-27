const std = @import("std");
const pine = @import("pine-engine");

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var app = try pine.App.init(allocator, .{});
    defer app.deinit();

    // add plugins
    try app.addPlugin(pine.RenderTerminalPlugin);

    // add systems
    try app.addSystem("startup", SetupSystem);
    try app.addSystem("update.main", PlayerMoveSystem);
    try app.addSystem("update.main", ShutdownSystem);

    try app.run();
}

const Player = struct {};

const SetupSystem = struct {
    pub fn process(_: *SetupSystem, registry: *pine.ecs.Registry) anyerror!void {
        // spawn the player
        _ = try registry.spawn(.{
            Player{},
            pine.TermPositionComponent{ .x = 5, .y = 5 },
            pine.TermSpriteComponent{
                .symbol = '@',
                .color = pine.terminal.TermColor.fromRGB(
                    pine.terminal.colors.white.rgb,
                    pine.terminal.colors.black.rgb,
                ),
            },
        });
    }
};

const PlayerMoveSystem = struct {
    pub fn process(_: *PlayerMoveSystem, registry: *pine.ecs.Registry) anyerror!void {
        var key_events = switch (try registry.queryResource(pine.terminal.KeyEvent)) {
            .collection => |col| col,
            .single => unreachable,
        };
        defer key_events.deinit();

        var positions = try registry.queryComponents(.{ pine.TermPositionComponent, Player });
        defer positions.deinit();

        while (positions.next()) |position| {
            const p = position.get(pine.TermPositionComponent).?;

            while (key_events.next()) |event| {
                switch (event) {
                    .arrow => |arrow| {
                        switch (arrow) {
                            .left => {
                                if (p.x > 0) p.*.x -= 1;
                            },
                            .right => p.*.x += 1,
                            .up => {
                                if (p.y > 0) p.*.y -= 1;
                            },
                            .down => p.*.y += 1,
                        }
                    },
                    else => {},
                }
            }
        }
    }
};

const ShutdownSystem = struct {
    pub fn process(_: *ShutdownSystem, registry: *pine.ecs.Registry) anyerror!void {
        var key_events = switch (try registry.queryResource(pine.terminal.KeyEvent)) {
            .collection => |col| col,
            .single => unreachable,
        };
        defer key_events.deinit();

        while (key_events.next()) |event| {
            switch (event) {
                .char => |c| if (c == 'q') try registry.pushResource(
                    pine.Message{ .shutdown = .requested },
                ),
                else => {},
            }
        }
    }
};
