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
    try app.addSystem("update.main", LightingSystem);
    try app.addSystem("render.main", PlayerHudSystem);

    try app.run();
}

const PlayerComponent = struct {};
const HealthComponent = struct {
    hp: u8,
};

const WalkableComponent = struct {};
const UnwalkableComponent = struct {};

const TileComponent = enum {
    floor,
    wall,
    water,
    grass,
    torch,

    const Appearance = struct {
        symbol: u21,
        color: pine.terminal.TermColor,
    };

    fn getAppearance(self: TileComponent) Appearance {
        return switch (self) {
            .floor => .{ .symbol = '.', .color = pine.terminal.TermColor.fromRGB(
                .{ .r = 100, .g = 100, .b = 100 },
                .{ .r = 20, .g = 20, .b = 20 },
            ) },
            .wall => .{ .symbol = '#', .color = pine.terminal.TermColor.fromRGB(
                .{ .r = 136, .g = 140, .b = 141 },
                .{ .r = 40, .g = 40, .b = 40 },
            ) },
            .water => .{ .symbol = '~', .color = pine.terminal.TermColor.fromRGB(
                .{ .r = 33, .g = 150, .b = 243 },
                .{ .r = 10, .g = 50, .b = 100 },
            ) },
            .grass => .{ .symbol = '"', .color = pine.terminal.TermColor.fromRGB(
                .{ .r = 46, .g = 125, .b = 50 },
                .{ .r = 20, .g = 40, .b = 20 },
            ) },
            .torch => .{ .symbol = '†', .color = pine.terminal.TermColor.fromRGB(
                .{ .r = 255, .g = 200, .b = 0 },
                .{ .r = 100, .g = 50, .b = 0 },
            ) },
        };
    }
};

const LightSourceComponent = struct {
    intensity: f32,
    color: pine.terminal.ColorRGB,
    flicker: bool,
};

const SetupSystem = struct {
    pub fn init(_: Allocator) anyerror!SetupSystem {
        return SetupSystem{};
    }

    pub fn process(_: *SetupSystem, registry: *pine.ecs.Registry) anyerror!void {
        // spawn the map
        try spawn_map(registry);

        // spawn the lights sources
        // try spawn_light_sources(registry);

        // spawn the player
        const player_pos: struct {
            x: u16,
            y: u16,
        } = .{ .x = 5, .y = 5 };

        _ = try registry.spawn(.{
            PlayerComponent{},
            HealthComponent{ .hp = 10 },
            pine.TermPositionComponent{
                .x = player_pos.x,
                .y = player_pos.y,
            },
            pine.TermSpriteComponent{
                .symbol = '@',
                .color = pine.terminal.TermColor.fromRGB(
                    pine.terminal.colors.white.rgb,
                    pine.terminal.colors.dark_gray.rgb,
                ),
            },
            LightSourceComponent{
                .intensity = 5,
                .color = .{ .r = 200, .g = 200, .b = 150 },
                .flicker = false,
            },
        });
    }

    fn spawn_map(registry: *pine.ecs.Registry) !void {
        // create a simple map
        const MAP_WIDTH = 50;
        const MAP_HEIGHT = 25;
        var map: [MAP_HEIGHT][MAP_WIDTH]TileComponent = undefined;

        // initialize map
        for (&map) |*row| {
            for (row) |*tile| {
                tile.* = .floor;
            }
        }

        // add some features
        // walls around the edge
        for (0..MAP_WIDTH) |x| {
            map[0][x] = .wall;
            map[MAP_HEIGHT - 1][x] = .wall;
        }
        for (0..MAP_HEIGHT) |y| {
            map[y][0] = .wall;
            map[y][MAP_WIDTH - 1] = .wall;
        }

        // add a room
        for (10..20) |x| {
            map[5][x] = .wall;
            map[15][x] = .wall;
        }
        for (5..16) |y| {
            map[y][10] = .wall;
            map[y][19] = .wall;
        }

        // add water feature
        for (25..35) |x| {
            for (8..12) |y| {
                map[y][x] = .water;
            }
        }

        // add grass area
        for (30..40) |x| {
            for (16..20) |y| {
                map[y][x] = .grass;
            }
        }

        // add torches
        map[5][11] = .torch;
        map[5][18] = .torch;
        map[15][11] = .torch;
        map[15][18] = .torch;

        // spawn tile entities
        for (0..MAP_HEIGHT) |y| {
            for (0..MAP_WIDTH) |x| {
                const appearance = map[y][x].getAppearance();
                switch (map[y][x]) {
                    .wall => _ = try registry.spawn(.{
                        map[y][x], // tile component
                        pine.TermPositionComponent{
                            .x = @intCast(x),
                            .y = @intCast(y),
                        },
                        pine.TermSpriteComponent{
                            .symbol = appearance.symbol,
                            .color = appearance.color,
                        },
                        UnwalkableComponent{},
                    }),
                    else => _ = try registry.spawn(.{
                        map[y][x], // tile component
                        pine.TermPositionComponent{
                            .x = @intCast(x),
                            .y = @intCast(y),
                        },
                        pine.TermSpriteComponent{
                            .symbol = appearance.symbol,
                            .color = appearance.color,
                        },
                        WalkableComponent{},
                    }),
                }
            }
        }
    }

    fn spawn_light_sources(registry: *pine.ecs.Registry) !void {
        _ = try registry.spawn(.{
            LightSourceComponent{
                .intensity = 8,
                .color = .{ .r = 255, .g = 150, .b = 50 },
                .flicker = true,
            },
            pine.TermPositionComponent{ .x = 11, .y = 5 },
        });
        _ = try registry.spawn(.{
            LightSourceComponent{
                .intensity = 8,
                .color = .{ .r = 255, .g = 150, .b = 50 },
                .flicker = true,
            },
            pine.TermPositionComponent{
                .x = 18,
                .y = 5,
            },
        });
        _ = try registry.spawn(.{
            LightSourceComponent{
                .intensity = 8,
                .color = .{ .r = 255, .g = 150, .b = 50 },
                .flicker = true,
            },
            pine.TermPositionComponent{
                .x = 11,
                .y = 15,
            },
        });
        _ = try registry.spawn(.{
            LightSourceComponent{
                .intensity = 8,
                .color = .{ .r = 255, .g = 150, .b = 50 },
                .flicker = true,
            },
            pine.TermPositionComponent{
                .x = 18,
                .y = 15,
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

        var player_query = try registry.queryComponents(.{ pine.TermPositionComponent, LightSourceComponent, PlayerComponent });
        defer player_query.deinit();

        while (player_query.next()) |player| {
            const p_pos = player.get(pine.TermPositionComponent).?;

            while (key_events.next()) |event| {
                switch (event) {
                    .arrow => |arrow| {
                        var wall_positions = try registry.queryComponents(.{ pine.TermPositionComponent, UnwalkableComponent });
                        defer wall_positions.deinit();

                        var can_walk_left = true;
                        var can_walk_right = true;
                        var can_walk_up = true;
                        var can_walk_down = true;

                        // check if the player brushes up against a wall
                        while (wall_positions.next()) |wall_position| {
                            const wall = wall_position.get(pine.TermPositionComponent).?;

                            if (wall.x == p_pos.x - 1 and wall.y == p_pos.y) {
                                can_walk_left = false;
                            }
                            if (wall.x == p_pos.x + 1 and wall.y == p_pos.y) {
                                can_walk_right = false;
                            }
                            if (wall.x == p_pos.x and wall.y == p_pos.y - 1) {
                                can_walk_up = false;
                            }
                            if (wall.x == p_pos.x and wall.y == p_pos.y + 1) {
                                can_walk_down = false;
                            }
                        }

                        switch (arrow) {
                            .left => {
                                if (p_pos.x > 0 and can_walk_left) {
                                    p_pos.*.x -= 1;
                                }
                            },
                            .right => {
                                if (can_walk_right) {
                                    p_pos.*.x += 1;
                                }
                            },
                            .up => {
                                if (p_pos.y > 0 and can_walk_up) {
                                    p_pos.*.y -= 1;
                                }
                            },
                            .down => {
                                if (can_walk_down) {
                                    p_pos.*.y += 1;
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

const PlayerHudSystem = struct {
    pub fn process(_: *PlayerHudSystem, registry: *pine.ecs.Registry) anyerror!void {
        var screen = switch (try registry.queryResource(pine.terminal.Screen)) {
            .single => |screen| screen.resource orelse return error.InvalidResource,
            .collection => return error.InvalidResource,
        };

        const ui_y = 0;
        screen.drawString(0, ui_y, "Health: ", pine.terminal.TermColor.fromPalette(7, 0));

        const health_percent: f32 = 0.75; // 75% health
        const bar_width = 20;
        for (0..bar_width) |i| {
            const filled = i < @as(usize, @intFromFloat(bar_width * health_percent));
            if (filled) {
                // gradient from green to red based on position
                const gradient_pos = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(bar_width));
                const bar_color = pine.terminal.colors.blendRgb(
                    .{ .r = 67, .g = 160, .b = 71 }, // green
                    .{ .r = 229, .g = 57, .b = 53 }, // red
                    gradient_pos,
                );
                screen.setCell(8 + @as(u16, @intCast(i)), ui_y, '█', pine.terminal.TermColor.fromRGB(
                    bar_color,
                    .{ .r = 0, .g = 0, .b = 0 },
                ));
            } else {
                screen.setCell(8 + @as(u16, @intCast(i)), ui_y, '█', pine.terminal.TermColor.fromRGB(
                    pine.terminal.colors.dark_gray.rgb,
                    pine.terminal.colors.black.rgb,
                ));
            }
        }
    }
};

const LightingSystem = struct {
    time: f32,

    pub fn init(_: Allocator) anyerror!LightingSystem {
        return LightingSystem{ .time = 0 };
    }

    pub fn process(self: *LightingSystem, registry: *pine.ecs.Registry) anyerror!void {
        var light_query = try registry.queryComponents(.{ pine.TermPositionComponent, LightSourceComponent });
        defer light_query.deinit();

        while (light_query.next()) |light| {
            const light_pos = light.get(pine.TermPositionComponent).?;
            const light_properties = light.get(LightSourceComponent).?;

            var tile_query = try registry.queryComponents(.{ pine.TermPositionComponent, pine.TermSpriteComponent, TileComponent });
            defer tile_query.deinit();

            while (tile_query.next()) |tile| {
                const tile_sprite = tile.get(pine.TermSpriteComponent).?;
                const tile_pos = tile.get(pine.TermPositionComponent).?;
                const tile_type = tile.get(TileComponent).?;
                const tile_appearance = tile_type.getAppearance();

                // apply lighting
                var lit_fg = switch (tile_appearance.color.fg) {
                    .rgb => |rgb| rgb,
                    .palette => pine.terminal.colors.palette256ToRgb(tile_appearance.color.fg.palette),
                };
                var lit_bg = switch (tile_appearance.color.bg) {
                    .rgb => |rgb| rgb,
                    .palette => pine.terminal.colors.palette256ToRgb(tile_appearance.color.bg.palette),
                };

                // start with darkness
                lit_fg = pine.terminal.colors.darken(lit_fg, 0.8);
                lit_bg = pine.terminal.colors.darken(lit_bg, 0.9);

                var intensity = light_properties.intensity;

                // add flicker effect
                if (light_properties.flicker) {
                    intensity += @sin(self.time * 10.0 + @as(f32, @floatFromInt(light_pos.x + light_pos.y))) * 1.5;
                }

                const light_color = pine.terminal.colors.calculateLighting(
                    lit_fg,
                    .{
                        .x = @intCast(light_pos.x),
                        .y = @intCast(light_pos.y),
                        .intensity = intensity,
                        .color = light_properties.color,
                    },
                    .{ .x = @intCast(tile_pos.x), .y = @intCast(tile_pos.y) },
                );

                lit_fg = light_color;

                // special effects for certain tiles
                if (tile_type.* == .water) {
                    // animate water
                    const wave = @sin(self.time * 2.0 + @as(f64, @floatFromInt(tile_pos.x + tile_pos.y))) * 0.2 + 0.5;
                    lit_fg = pine.terminal.colors.lighten(lit_fg, @as(f32, @floatCast(wave)) * 0.3);
                    tile_sprite.symbol = if (wave > 0.5) '≈' else '~';
                }

                tile_sprite.color = pine.terminal.TermColor.fromRGB(lit_fg, lit_bg);
            }
        }

        // update time for animations
        self.time += 0.006125;
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
