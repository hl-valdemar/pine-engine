const std = @import("std");
const sokol = @import("sokol");
const pine = @import("pine");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

const cube_desc = struct {
    const label = "cube-example";

    const vertices = [_]f32{
        // positions      colors
        //
        // NSColor(red: 0.275, green: 0.259, blue: 0.369, alpha: 1)
        -1.0, -1.0, -1.0, 0.275,  0.259, 0.369, 1.0,
        1.0,  -1.0, -1.0, 0.275,  0.259, 0.369, 1.0,
        1.0,  1.0,  -1.0, 0.275,  0.259, 0.369, 1.0,
        -1.0, 1.0,  -1.0, 0.275,  0.259, 0.369, 1.0,

        // NSColor(red: 0.0824, green: 0.471, blue: 0.549, alpha: 1)
        -1.0, -1.0, 1.0,  0.0824, 0.471, 0.549, 1.0,
        1.0,  -1.0, 1.0,  0.0824, 0.471, 0.549, 1.0,
        1.0,  1.0,  1.0,  0.0824, 0.471, 0.549, 1.0,
        -1.0, 1.0,  1.0,  0.0824, 0.471, 0.549, 1.0,

        // NSColor(red: 0, green: 0.725, blue: 0.745, alpha: 1)
        -1.0, -1.0, -1.0, 0.0,    0.725, 0.745, 1.0,
        -1.0, 1.0,  -1.0, 0.0,    0.725, 0.745, 1.0,
        -1.0, 1.0,  1.0,  0.0,    0.725, 0.745, 1.0,
        -1.0, -1.0, 1.0,  0.0,    0.725, 0.745, 1.0,

        // NSColor(red: 1, green: 0.933, blue: 0.8, alpha: 1)
        1.0,  -1.0, -1.0, 1.0,    0.933, 0.8,   1.0,
        1.0,  1.0,  -1.0, 1.0,    0.933, 0.8,   1.0,
        1.0,  1.0,  1.0,  1.0,    0.933, 0.8,   1.0,
        1.0,  -1.0, 1.0,  1.0,    0.933, 0.8,   1.0,

        // NSColor(red: 1, green: 0.69, blue: 0.639, alpha: 1)
        -1.0, -1.0, -1.0, 1.0,    0.69,  0.639, 1.0,
        -1.0, -1.0, 1.0,  1.0,    0.69,  0.639, 1.0,
        1.0,  -1.0, 1.0,  1.0,    0.69,  0.639, 1.0,
        1.0,  -1.0, -1.0, 1.0,    0.69,  0.639, 1.0,

        // NSColor(red: 1, green: 0.412, blue: 0.451, alpha: 1)
        -1.0, 1.0,  -1.0, 1.0,    0.412, 0.451, 1.0,
        -1.0, 1.0,  1.0,  1.0,    0.412, 0.451, 1.0,
        1.0,  1.0,  1.0,  1.0,    0.412, 0.451, 1.0,
        1.0,  1.0,  -1.0, 1.0,    0.412, 0.451, 1.0,
    };

    const indices = [_]u32{
        0,  1,  2,  0,  2,  3,
        6,  5,  4,  7,  6,  4,
        8,  9,  10, 8,  10, 11,
        14, 13, 12, 15, 14, 12,
        16, 17, 18, 16, 18, 19,
        22, 21, 20, 23, 22, 20,
    };
};

const WorldState = struct {
    var cube_node_id: u64 = 0;

    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,
    camera: pine.Camera,
    renderer: pine.Renderer,
    scene: pine.Scene,

    pub fn init(allocator: std.mem.Allocator) !WorldState {
        const camera = pine.Camera.init(
            pine.math.Vec3.with(1, 2, 6),
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
            .init_userdata_cb = sokolInitCubeExample,
            .frame_userdata_cb = sokolFrameCubeExample,
            .event_userdata_cb = sokolEventCubeExample,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Pine: Cube Example",
        });
    }

    export fn sokolInitCubeExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

            const cube_mesh_id = self.resource_manager.createMesh(cube_desc.label, &cube_desc.vertices, &cube_desc.indices) catch |err| {
                std.log.err("failed to create cube mesh: {}", .{err});
                @panic("FAILED TO CREATE CUBE MESH!\n");
            };

            const cube_shader_id = self.resource_manager.createShader(
                cube_desc.label,
                @embedFile("shaders/cube.vs.metal"),
                @embedFile("shaders/cube.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create cube shader: {}", .{err});
                @panic("FAILED TO CREATE CUBE SHADER!\n");
            };

            const cube_material_id = self.resource_manager.createMaterial(cube_desc.label, cube_shader_id) catch |err| {
                std.log.err("failed to create cube material: {}", .{err});
                @panic("FAILED TO CREATE CUBE MATERIAL!\n");
            };

            // create the cube node and add it to the scene
            var cube_node = self.scene.createNode(cube_desc.label) catch {
                @panic("FAILED TO CREATE CUBE NODE!\n");
            };
            cube_node.mesh_id = cube_mesh_id;
            cube_node.material_id = cube_material_id;
            self.scene.root.addChild(cube_node) catch {
                @panic("FAILED TO ADD CUBE NODE TO SCENE!\n");
            };

            cube_node_id = cube_node.id;
        }
    }

    export fn sokolFrameCubeExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            const cube_node = self.scene.getNodeByUID(cube_node_id);
            if (cube_node) |cube| {
                cube.*.transform.rotate(
                    pine.math.Vec3.with(0, 1, 1),
                    @floatCast(dt * 0.5),
                );
            }

            self.renderer.renderScene(&self.scene, &self.resource_manager);
        }
    }

    export fn sokolEventCubeExample(ev: [*c]const sokol.app.Event, world_state: ?*anyopaque) void {
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
