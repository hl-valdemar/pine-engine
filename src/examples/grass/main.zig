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
    var terrain_node_id: pine.UniqueIDType = pine.UniqueID.INVALID;

    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,
    camera: pine.Camera,
    renderer: pine.Renderer,
    scene: pine.Scene,
    grid: Grid,
    grass: Grass,

    pub fn init(allocator: std.mem.Allocator, terrain_type: []const u8) !WorldState {
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
            .scene = try pine.Scene.init(allocator),
            .grid = grid,
            .grass = grass,
        };
    }

    pub fn deinit(self: *WorldState) void {
        self.resource_manager.deinit();
        self.renderer.deinit();
        self.scene.deinit();

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

            // terrain
            const terrain_mesh_id = self.resource_manager.createMesh(
                self.grid.label,
                &self.grid.vertices,
                null,
                &self.grid.colors,
                &self.grid.indices_filled,
            ) catch |err| {
                std.log.err("failed to create terrain mesh: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MESH!\n");
            };
            const terrain_shader_id = self.resource_manager.createShader(
                self.grid.label,
                @embedFile("shaders/terrain.vs.metal"),
                @embedFile("shaders/terrain.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create terrain shader: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN SHADER!\n");
            };
            const terrain_material_id = self.resource_manager.createMaterial(self.grid.label) catch |err| {
                std.log.err("failed to create terrain material: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MATERIAL!\n");
            };
            if (self.resource_manager.getMaterial(terrain_material_id)) |m| {
                m.addShaderPass(pine.ShaderPass{ .shader_id = terrain_shader_id }) catch {
                    @panic("FAILED TO ADD SHADER PASS TO TERRAIN MATERIAL!\n");
                };
            }

            // grass
            const grass_mesh_id = self.resource_manager.createMesh(
                self.grass.label,
                &Grass.vertices,
                null,
                &Grass.colors,
                &Grass.indices,
            ) catch |err| {
                std.log.err("failed to create grass mesh: {}", .{err});
                @panic("FAILED TO CREATE GRASS MESH!\n");
            };
            const grass_shader_id = self.resource_manager.createShader(
                self.grass.label,
                @embedFile("shaders/grass.vs.metal"),
                @embedFile("shaders/grass.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create grass shader: {}", .{err});
                @panic("FAILED TO CREATE GRASS SHADER!\n");
            };
            const grass_material_id = self.resource_manager.createMaterial(self.grass.label) catch |err| {
                std.log.err("failed to create grass material: {}", .{err});
                @panic("FAILED TO CREATE GRASS MATERIAL!\n");
            };
            if (self.resource_manager.getMaterial(grass_material_id)) |m| {
                m.addShaderPass(pine.ShaderPass{ .shader_id = grass_shader_id }) catch {
                    @panic("FAILED TO ADD SHADER PASS TO GRASS MATERIAL!\n");
                };
            }

            // create the terrain node and add it to the root of the scene
            const terrain_node = self.scene.createNode("terrain") catch {
                @panic("FAILED TO CREATE TERRAIN NODE!\n");
            };
            terrain_node.mesh_id = terrain_mesh_id;
            terrain_node.material_id = terrain_material_id;
            self.scene.root.addChild(terrain_node) catch {
                @panic("FAILED TO ADD TERRAIN NODE TO SCENE!\n");
            };
            terrain_node_id = terrain_node.id;

            // create the grass node and add it as a child to the terrain node
            const grass_node = self.scene.createNode("grass") catch {
                @panic("FAILED TO CREATE GRASS NODE!\n");
            };
            grass_node.mesh_id = grass_mesh_id;
            grass_node.material_id = grass_material_id;
            terrain_node.addChild(grass_node) catch {
                @panic("FAILED TO ADD GRASS NODE TO SCENE!\n");
            };
        }
    }

    export fn sokolFrameGrassExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();
            const rotational_constant = 0.25;

            if (self.scene.getNodeByUID(terrain_node_id)) |terrain| {
                terrain.transform.rotate(
                    pine.math.Vec3.up(),
                    @floatCast(dt * rotational_constant),
                );
            }

            self.renderer.renderScene(&self.scene, &self.resource_manager);
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

    var world = WorldState.init(allocator, terrain_type) catch {
        @panic("FAILED TO INITIALIZE WORLD STATE!\n");
    };
    defer world.deinit();

    world.run();
}
