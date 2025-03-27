const std = @import("std");
const pine = @import("pine");
const sokol = @import("sokol");

const Grid = @import("terrain.zig").Grid;

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

    pub fn init(allocator: std.mem.Allocator) !WorldState {
        const camera = pine.Camera.init(
            pine.math.Vec3.with(40, 30, 40),
            pine.math.Vec3.zeros(),
            60,
            4 / 3,
            0.01,
            100,
        );

        return .{
            .allocator = allocator,
            .resource_manager = pine.ResourceManager.init(allocator),
            .camera = camera,
            .renderer = pine.Renderer.init(allocator, camera),
            .scene = try pine.Scene.init(allocator),
            .grid = Grid.init("grid-example"),
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
            .init_userdata_cb = sokolInitTerrainExample,
            .frame_userdata_cb = sokolFrameTerrainExample,
            .event_userdata_cb = sokolEventTerrainExample,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Pine: Terrain Example",
        });
    }

    export fn sokolInitTerrainExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

            const mesh_id = self.resource_manager.createMesh(
                self.grid.label,
                &self.grid.vertices,
                null,
                &self.grid.indices_filled,
            ) catch |err| {
                std.log.err("failed to create terrain mesh: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MESH!\n");
            };

            const shader_id = self.resource_manager.createShader(
                self.grid.label,
                @embedFile("shaders/terrain.vs.metal"),
                @embedFile("shaders/terrain.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create terrain shader: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN SHADER!\n");
            };

            const material_id = self.resource_manager.createMaterial(
                self.grid.label,
                shader_id,
            ) catch |err| {
                std.log.err("failed to create terrain material: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MATERIAL!\n");
            };

            const terrain_node = self.scene.createNode("terrain") catch {
                @panic("FAILED TO CREATE TERRAIN NODE!\n");
            };
            terrain_node.mesh_id = mesh_id;
            terrain_node.material_id = material_id;
            self.scene.root.addChild(terrain_node) catch {
                @panic("FAILED TO ADD TERRAIN NODE TO SCENE!\n");
            };

            terrain_node_id = terrain_node.id;
        }
    }

    export fn sokolFrameTerrainExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            const terrain_node = self.scene.getNodeByUID(terrain_node_id);
            if (terrain_node) |terrain| {
                terrain.*.transform.rotate(
                    pine.math.Vec3.up(),
                    @floatCast(dt * 0.25),
                );
            }

            self.renderer.renderScene(&self.scene, &self.resource_manager);
        }
    }

    export fn sokolEventTerrainExample(ev: [*c]const sokol.app.Event, world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));
            _ = self;

            if (ev.*.key_code == .ESCAPE and ev.*.type == .KEY_DOWN) {
                sokol.app.requestQuit();
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("memory leak detected!\n", .{});
    }

    var world = WorldState.init(allocator) catch {
        @panic("FAILED TO INITIALIZE WORLD STATE!\n");
    };
    defer world.deinit();

    world.run();
}
