const Allocator = @import("std").mem.Allocator;

const pine = @import("pine-engine");

const component = @import("component.zig");
const util = @import("util.zig");

pub const Setup = struct {
    pub fn process(_: *Setup, registry: *pine.ecs.Registry) anyerror!void {
        // spawn the map
        try spawn_map(registry);

        // spawn the player
        const player_pos: struct {
            x: u16,
            y: u16,
        } = .{ .x = 5, .y = 5 };

        // somewhat hacky fix to a lighting problem
        const tile: component.Tile = .player;
        const appearance = tile.getAppearance();

        _ = try registry.spawn(.{
            component.Player{},
            component.Health{ .hp = 10 },
            pine.component.TermPosition{
                .x = player_pos.x,
                .y = player_pos.y,
            },
            pine.component.TermSprite{
                .symbol = appearance.symbol,
                .color = appearance.color,
            },
            component.LightSource{
                .intensity = 5,
                .color = appearance.color.fg.rgb,
                .flicker = false,
            },
            tile,
        });
    }

    fn spawn_map(registry: *pine.ecs.Registry) !void {
        // create a simple map
        const MAP_WIDTH = 50;
        const MAP_HEIGHT = 25;
        var map: [MAP_HEIGHT][MAP_WIDTH]component.Tile = undefined;

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
        const Y_OFF = 1;
        for (0..MAP_HEIGHT) |y| {
            for (0..MAP_WIDTH) |x| {
                const tile = map[y][x];
                const appearance = tile.getAppearance();

                const position =
                    pine.component.TermPosition{
                        .x = @intCast(x),
                        .y = @intCast(y + Y_OFF),
                    };

                const sprite =
                    pine.component.TermSprite{
                        .symbol = appearance.symbol,
                        .color = appearance.color,
                    };

                switch (tile) {
                    .wall => _ = try registry.spawn(.{
                        tile,
                        position,
                        sprite,
                        component.Unwalkable{},
                    }),
                    .torch => _ = try registry.spawn(.{
                        tile,
                        position,
                        sprite,
                        component.LightSource{
                            .intensity = 8,
                            .color = .{ .r = 255, .g = 150, .b = 50 },
                            .flicker = true,
                        },
                    }),
                    else => _ = try registry.spawn(.{
                        tile,
                        position,
                        sprite,
                    }),
                }
            }
        }
    }
};

pub const PlayerMove = struct {
    pub fn process(_: *PlayerMove, registry: *pine.ecs.Registry) anyerror!void {
        var event_query = switch (try registry.queryResource(pine.terminal.KeyEvent)) {
            .collection => |col| col,
            .single => unreachable,
        };
        defer event_query.deinit();

        var player_query = try registry.queryComponents(.{
            pine.component.TermPosition,
            component.Player,
        });
        defer player_query.deinit();

        while (player_query.next()) |player| {
            const p_pos = player.get(pine.component.TermPosition).?;

            while (event_query.next()) |key_event| {
                switch (key_event) {
                    .arrow => |arrow| {
                        var wall_query = try registry.queryComponents(.{
                            pine.component.TermPosition,
                            component.Unwalkable,
                        });
                        defer wall_query.deinit();

                        var can_walk_left = true;
                        var can_walk_right = true;
                        var can_walk_up = true;
                        var can_walk_down = true;

                        // check if the player brushes up against a wall
                        while (wall_query.next()) |wall_position| {
                            const wall = wall_position.get(pine.component.TermPosition).?;

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

pub const PlayerHud = struct {
    pub fn process(_: *PlayerHud, registry: *pine.ecs.Registry) anyerror!void {
        var screen = switch (try registry.queryResource(pine.terminal.Screen)) {
            .single => |screen| screen.resource orelse return error.InvalidResource,
            .collection => return error.InvalidResource,
        };

        const ui_y = 0;
        const hp_tag = "hp: ";
        screen.drawString(0, ui_y, hp_tag, pine.terminal.TermColor.fromRGB(
            pine.terminal.colors.lighten(pine.terminal.colors.black.rgb, 0.2),
            pine.terminal.colors.black.rgb,
        ));

        // const hp_bar_symbol = '■';
        // const hp_bar_symbol = '◦';
        // const hp_bar_symbol = '-';
        const hp_bar_symbol = '=';

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
                screen.setCell(@as(u16, @intCast(hp_tag.len + i)), ui_y, hp_bar_symbol, pine.terminal.TermColor.fromRGB(
                    bar_color,
                    pine.terminal.colors.black.rgb,
                ));
            } else {
                screen.setCell(@as(u16, @intCast(hp_tag.len + i)), ui_y, hp_bar_symbol, pine.terminal.TermColor.fromRGB(
                    pine.terminal.colors.lighten(pine.terminal.colors.black.rgb, 0.2),
                    pine.terminal.colors.black.rgb,
                ));
            }
        }
    }
};

pub const Lighting = struct {
    time: f32,

    pub fn init(_: Allocator) anyerror!Lighting {
        return Lighting{ .time = 0 };
    }

    pub fn process(self: *Lighting, registry: *pine.ecs.Registry) anyerror!void {
        // first, apply base darkness to all tiles
        var tile_query = try registry.queryComponents(.{
            pine.component.TermPosition,
            pine.component.TermSprite,
            component.Tile,
        });
        defer tile_query.deinit();

        // store original colors and apply darkness
        while (tile_query.next()) |tile| {
            const tile_sprite = tile.get(pine.component.TermSprite).?;
            const tile_type = tile.get(component.Tile).?;
            const tile_appearance = tile_type.getAppearance();

            // start with darkened base colors
            var base_fg = switch (tile_appearance.color.fg) {
                .rgb => |rgb| rgb,
                .palette => pine.terminal.colors.palette256ToRgb(tile_appearance.color.fg.palette),
            };
            var base_bg = switch (tile_appearance.color.bg) {
                .rgb => |rgb| rgb,
                .palette => pine.terminal.colors.palette256ToRgb(tile_appearance.color.bg.palette),
            };

            // apply darkness
            base_fg = pine.terminal.colors.darken(base_fg, 0.8);
            base_bg = pine.terminal.colors.darken(base_bg, 0.9);

            // set the darkened color as base
            tile_sprite.color = pine.terminal.TermColor.fromRGB(base_fg, base_bg);
        }

        // then, for each light source, add its contribution
        var light_query = try registry.queryComponents(.{ pine.component.TermPosition, component.LightSource });
        defer light_query.deinit();

        while (light_query.next()) |light| {
            const light_pos = light.get(pine.component.TermPosition).?;
            const light_properties = light.get(component.LightSource).?;

            var intensity = light_properties.intensity;
            if (light_properties.flicker) {
                intensity += @sin(self.time * 10.0 + @as(f32, @floatFromInt(light_pos.x * 7 + light_pos.y * 13))) * 1.0;
            }

            // apply this light's contribution to nearby tiles
            var affected_tiles = try registry.queryComponents(.{
                pine.component.TermPosition,
                pine.component.TermSprite,
                component.Tile,
            });
            defer affected_tiles.deinit();

            while (affected_tiles.next()) |tile| {
                const tile_pos = tile.get(pine.component.TermPosition).?;
                const tile_sprite = tile.get(pine.component.TermSprite).?;
                const tile_kind = tile.get(component.Tile).?;

                // get current color
                var current_fg = switch (tile_sprite.color.fg) {
                    .rgb => |rgb| rgb,
                    .palette => pine.terminal.colors.palette256ToRgb(tile_sprite.color.fg.palette),
                };

                // calculate and add this light's contribution
                const light_contribution = util.calculateLighting(
                    current_fg,
                    .{
                        .x = @intCast(light_pos.x),
                        .y = @intCast(light_pos.y),
                        .intensity = intensity,
                        .color = light_properties.color,
                    },
                    .{ .x = @intCast(tile_pos.x), .y = @intCast(tile_pos.y) },
                );

                // blend the contribution with current color (additive lighting)
                current_fg = pine.terminal.colors.blendRgb(current_fg, light_contribution, 0.5);

                // update the tile color
                const current_bg = switch (tile_sprite.color.bg) {
                    .rgb => |rgb| rgb,
                    .palette => pine.terminal.colors.palette256ToRgb(tile_sprite.color.bg.palette),
                };
                tile_sprite.color = pine.terminal.TermColor.fromRGB(current_fg, current_bg);

                // special effects for certain tiles
                if (tile_kind.* == .water) {
                    // animate water
                    const wave = @sin(self.time * 2.0 + @as(f32, @floatFromInt(tile_pos.x + tile_pos.y))) * 0.2 + 0.5;
                    current_fg = pine.terminal.colors.lighten(current_fg, wave * 0.3);
                    tile_sprite.symbol = if (wave > 0.5) '≈' else '~';
                }
            }
        }

        // update time more slowly
        self.time += 0.006125; // TODO: use proper delta time
    }
};

pub const Shutdown = struct {
    pub fn process(_: *Shutdown, registry: *pine.ecs.Registry) anyerror!void {
        var event_query = switch (try registry.queryResource(pine.terminal.KeyEvent)) {
            .collection => |col| col,
            .single => unreachable,
        };
        defer event_query.deinit();

        while (event_query.next()) |key_event| {
            switch (key_event) {
                .char => |c| if (c == 'q') try registry.pushResource(
                    pine.Message{ .shutdown = .requested },
                ),
                else => {},
            }
        }
    }
};
