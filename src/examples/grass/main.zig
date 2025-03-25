const std = @import("std");
const pine = @import("pine");
const sokol = @import("sokol");

const palette = @import("palettes.zig").palettes;

const Grid = @import("terrain.zig").Grid;
const Grass = @import("grass.zig").Grass;

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
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
                std.log.err("failed to add render command for terrain: {}", .{err});
            };
            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh(self.grass.label),
                .transform = grass_transform,
                .material = self.resource_manager.getMaterial(self.grass.label),
            }) catch |err| {
                std.log.err("failed to add render command for grass: {}", .{err});
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
