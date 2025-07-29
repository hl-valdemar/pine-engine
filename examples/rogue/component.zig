const pine = @import("pine-engine");

pub const Player = struct {};
pub const Health = struct {
    hp: u8,
};

pub const Unwalkable = struct {};

pub const Tile = enum {
    floor,
    wall,
    water,
    grass,
    torch,
    player,

    const Appearance = struct {
        symbol: u21,
        color: pine.terminal.TermColor,
    };

    pub fn getAppearance(self: Tile) Appearance {
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
            .player => .{
                .symbol = '@',
                .color = pine.terminal.TermColor.fromRGB(
                    .{ .r = 255, .g = 215, .b = 0 }, // golden glow
                    pine.terminal.colors.black.rgb,
                ),
            },
        };
    }
};

pub const LightSource = struct {
    intensity: f32,
    color: pine.terminal.ColorRGB,
    flicker: bool,
};
