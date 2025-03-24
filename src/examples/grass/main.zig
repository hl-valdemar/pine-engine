const std = @import("std");
const pine = @import("pine");
const sokol = @import("sokol");

const Grid = @import("terrain.zig").Grid;
const Grass = @import("grass.zig").Grass;

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

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

const WorldState = struct {
    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,
    camera: pine.Camera,
    renderer: pine.Renderer,
    grid: Grid,
    grass: Grass,

    pub fn init(allocator: std.mem.Allocator, terrain_type: []const u8) WorldState {
        const camera = pine.Camera.init(
            pine.math.Vec3.with(40, 30, 40),
            pine.math.Vec3.zeros(),
            60,
            4 / 3,
            0.01,
            100,
        );

        const grid = Grid.init("terrain-grid", terrain_type);
        const grass = Grass.init("terrain-grass", &grid);

        return .{
            .allocator = allocator,
            .resource_manager = pine.ResourceManager.init(allocator),
            .camera = camera,
            .renderer = pine.Renderer.init(allocator, camera),
            .grid = grid,
            .grass = grass,
        };
    }

    pub fn deinit(self: *WorldState) void {
        self.resource_manager.deinit();
        self.renderer.deinit();

        // important
        sokol.gfx.shutdown();
    }

    pub fn run(self: *WorldState) void {
        sokol.app.run(sokol.app.Desc{
            .init_userdata_cb = sokolInitGrassExample,
            .frame_userdata_cb = sokolFrameGrassExample,
            .event_userdata_cb = sokolEventGrassExample,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Pine: Grass Example",
        });
    }

    export fn sokolInitGrassExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

            self.resource_manager.createMesh(
                self.grid.label,
                &self.grid.vertices,
                &self.grid.indices_filled,
            ) catch |err| {
                std.log.err("failed to create terrain mesh: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MESH!\n");
            };
            self.resource_manager.createMesh(
                self.grass.label,
                &Grass.vertices,
                &Grass.indices,
            ) catch |err| {
                std.log.err("failed to create grass mesh: {}", .{err});
                @panic("FAILED TO CREATE GRASS MESH!\n");
            };

            self.resource_manager.createShader(
                self.grid.label,
                @embedFile("shaders/terrain.vs.metal"),
                @embedFile("shaders/terrain.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create terrain shader: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN SHADER!\n");
            };
            self.resource_manager.createShader(
                self.grass.label,
                @embedFile("shaders/grass.vs.metal"),
                @embedFile("shaders/grass.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create grass shader: {}", .{err});
                @panic("FAILED TO CREATE GRASS SHADER!\n");
            };

            self.resource_manager.createTransform(
                self.grid.label,
                pine.math.Vec3.zeros(),
                .{},
                pine.math.Vec3.ones(),
            ) catch |err| {
                std.log.err("failed to create terrain transform: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN TRANSFORM!\n");
            };
            self.resource_manager.createTransform(
                self.grass.label,
                pine.math.Vec3.zeros(),
                .{},
                pine.math.Vec3.ones(),
            ) catch |err| {
                std.log.err("failed to create grass transform: {}", .{err});
                @panic("FAILED TO CREATE GRASS TRANSFORM!\n");
            };

            self.resource_manager.createMaterial(self.grid.label, self.grid.label) catch |err| {
                std.log.err("failed to create terrain material: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MATERIAL!\n");
            };
            self.resource_manager.createMaterial(self.grass.label, self.grass.label) catch |err| {
                std.log.err("failed to create grass material: {}", .{err});
                @panic("FAILED TO CREATE GRASS MATERIAL!\n");
            };
        }
    }

    export fn sokolFrameGrassExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            // apply rotation
            const terrain_transform = if (self.resource_manager.getTransform(self.grid.label)) |transform| blk: {
                transform.rotation.angle += @floatCast(dt * 10);
                break :blk transform;
            } else blk: {
                break :blk null;
            };
            const grass_transform = if (self.resource_manager.getTransform(self.grass.label)) |transform| blk: {
                transform.rotation.angle += @floatCast(dt * 10);
                break :blk transform;
            } else blk: {
                break :blk null;
            };

            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh(self.grid.label),
                .transform = terrain_transform,
                .material = self.resource_manager.getMaterial(self.grid.label),
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };
            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh(self.grass.label),
                .transform = grass_transform,
                .material = self.resource_manager.getMaterial(self.grass.label),
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };

            self.renderer.render(&self.resource_manager);
        }
    }

    export fn sokolEventGrassExample(ev: [*c]const sokol.app.Event, world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));
            _ = self;

            if (ev.*.key_code == .ESCAPE and ev.*.type == .KEY_DOWN) {
                sokol.app.requestQuit();
            }
        }
    }
};

pub fn main(terrain_type: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("memory leak detected!\n", .{});
    }

    var world = WorldState.init(allocator, terrain_type);
    defer world.deinit();

    world.run();
}
