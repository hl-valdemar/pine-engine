const sokol = @import("sokol");

pub const palettes = struct {
    pub const basic = struct {
        pub const BLACK: sokol.gfx.Color = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1,
        };
        pub const LIGHT_BLUE: sokol.gfx.Color = .{
            .r = 0.5,
            .g = 0.7,
            .b = 0.9,
            .a = 1,
        };
    };

    pub const paper8 = struct {
        pub const BLUE_DARK: sokol.gfx.Color = .{
            .r = 0.122,
            .g = 0.141,
            .b = 0.294,
            .a = 1,
        };
        pub const MAGENTA_PINK_DARK: sokol.gfx.Color = .{
            .r = 0.396,
            .g = 0.251,
            .b = 0.325,
            .a = 1,
        };
        pub const RED: sokol.gfx.Color = .{
            .r = 0.659,
            .g = 0.376,
            .b = 0.365,
            .a = 1,
        };
        pub const ORANGE: sokol.gfx.Color = .{
            .r = 0.82,
            .g = 0.651,
            .b = 0.494,
            .a = 1,
        };
        pub const YELLOW_LIGHT: sokol.gfx.Color = .{
            .r = 0.965,
            .g = 0.906,
            .b = 0.612,
            .a = 1,
        };
        pub const CYAN: sokol.gfx.Color = .{
            .r = 0.235,
            .g = 0.42,
            .b = 0.392,
            .a = 1,
        };
        pub const BLUE_GREEN: sokol.gfx.Color = .{
            .r = 0.376,
            .g = 0.682,
            .b = 0.482,
            .a = 1,
        };
        pub const GREEN: sokol.gfx.Color = .{
            .r = 0.714,
            .g = 0.812,
            .b = 0.557,
            .a = 1,
        };
    };

    pub const ice_cream_gb = struct {
        pub const PINK_DARK: sokol.gfx.Color = .{
            .r = 0.486,
            .g = 0.247,
            .b = 0.345,
            .a = 1,
        };
        pub const RED: sokol.gfx.Color = .{
            .r = 0.922,
            .g = 0.42,
            .b = 0.435,
            .a = 1,
        };
        pub const ORANGE: sokol.gfx.Color = .{
            .r = 0.976,
            .g = 0.659,
            .b = 0.459,
            .a = 1,
        };
        pub const GRAYISH_YELLOW_LIGHT: sokol.gfx.Color = .{
            .r = 1,
            .g = 0.965,
            .b = 0.827,
            .a = 1,
        };
    };
};
