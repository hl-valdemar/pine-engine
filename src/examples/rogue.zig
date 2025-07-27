const std = @import("std");
const Allocator = std.mem.Allocator;

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

const PlayerComponent = struct {};
const WallComponent = struct {};

const SetupSystem = struct {
    pub fn init(_: Allocator) anyerror!SetupSystem {
        return SetupSystem{};
    }

    pub fn process(_: *SetupSystem, registry: *pine.ecs.Registry) anyerror!void {
        // spawn vertical walls
        const width = 10;
        const height = 10;
        for (2..12) |y| {
            _ = try registry.spawn(.{
                WallComponent{},
                pine.TermPositionComponent{
                    .x = @intCast(2),
                    .y = @intCast(y),
                },
                pine.TermSpriteComponent{
                    .symbol = '#',
                    .color = pine.terminal.TermColor.fromRGB(
                        pine.terminal.colors.white.rgb,
                        pine.terminal.colors.black.rgb,
                    ),
                },
            });
            _ = try registry.spawn(.{
                WallComponent{},
                pine.TermPositionComponent{
                    .x = @intCast(width - 1 + 2),
                    .y = @intCast(y),
                },
                pine.TermSpriteComponent{
                    .symbol = '#',
                    .color = pine.terminal.TermColor.fromRGB(
                        pine.terminal.colors.white.rgb,
                        pine.terminal.colors.black.rgb,
                    ),
                },
            });
        }
        // spawn horizontal walls
        for (2..12) |x| {
            _ = try registry.spawn(.{
                WallComponent{},
                pine.TermPositionComponent{
                    .x = @intCast(x),
                    .y = @intCast(2),
                },
                pine.TermSpriteComponent{
                    .symbol = '#',
                    .color = pine.terminal.TermColor.fromRGB(
                        pine.terminal.colors.white.rgb,
                        pine.terminal.colors.black.rgb,
                    ),
                },
            });
            _ = try registry.spawn(.{
                WallComponent{},
                pine.TermPositionComponent{
                    .x = @intCast(x),
                    .y = @intCast(height - 1 + 2),
                },
                pine.TermSpriteComponent{
                    .symbol = '#',
                    .color = pine.terminal.TermColor.fromRGB(
                        pine.terminal.colors.white.rgb,
                        pine.terminal.colors.black.rgb,
                    ),
                },
            });
        }

        // spawn the player
        _ = try registry.spawn(.{
            PlayerComponent{},
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

        var player_positions = try registry.queryComponents(.{ pine.TermPositionComponent, PlayerComponent });
        defer player_positions.deinit();

        while (player_positions.next()) |player_position| {
            const player = player_position.get(pine.TermPositionComponent).?;

            while (key_events.next()) |event| {
                switch (event) {
                    .arrow => |arrow| {
                        var wall_positions = try registry.queryComponents(.{ pine.TermPositionComponent, WallComponent });
                        defer wall_positions.deinit();

                        var can_walk_left = true;
                        var can_walk_right = true;
                        var can_walk_up = true;
                        var can_walk_down = true;

                        while (wall_positions.next()) |wall_position| {
                            const wall = wall_position.get(pine.TermPositionComponent).?;

                            if (wall.x == player.x - 1) {
                                can_walk_left = false;
                            } else if (wall.x == player.x + 1) {
                                can_walk_right = false;
                            }

                            if (wall.y == player.y - 1) {
                                can_walk_up = false;
                            } else if (wall.y == player.y + 1) {
                                can_walk_down = false;
                            }
                        }

                        switch (arrow) {
                            .left => {
                                if (player.x > 0 and can_walk_left) {
                                    player.*.x -= 1;
                                }
                            },
                            .right => {
                                if (can_walk_right) {
                                    player.*.x += 1;
                                }
                            },
                            .up => {
                                if (player.y > 0 and can_walk_up) {
                                    player.*.y -= 1;
                                }
                            },
                            .down => {
                                if (can_walk_down) {
                                    player.*.y += 1;
                                }
                            },
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
