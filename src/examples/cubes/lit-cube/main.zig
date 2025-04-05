const std = @import("std");
const sokol = @import("sokol");
const pine = @import("pine");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

const WorldState = struct {
    const cube_label: []const u8 = "lit-cube-example";

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
            .init_userdata_cb = sokolInitLitCubeExample,
            .frame_userdata_cb = sokolFrameLitCubeExample,
            .event_userdata_cb = sokolEventLitCubeExample,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Pine: Lit Cube Example",
        });
    }

    export fn sokolInitLitCubeExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

            self.renderer.initAfterSokol();

            const cube_mesh_id = self.resource_manager.createMesh(
                cube_label,
                &pine.primitive.Cube.VERTICES,
                &pine.primitive.Cube.NORMALS,
                null,
                &pine.primitive.Cube.INDICES,
            ) catch unreachable;

            const cube_shader_id = self.resource_manager.createShader(
                cube_label,
                pine.primitive.Cube.BASE_VS_SHADER,
                pine.primitive.Cube.BASE_FS_SHADER,
                sokol.gfx.queryBackend(),
            ) catch unreachable;

            const lighting_shader_id = self.resource_manager.createShader(
                "lighting-shader",
                @embedFile("shaders/lighting.vs.metal"),
                @embedFile("shaders/lighting.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch unreachable;

            const cube_material_id = self.resource_manager.createMaterial(cube_label) catch unreachable;

            if (self.resource_manager.getMaterial(cube_material_id)) |m| {
                m.addShaderPass(pine.ShaderPass{ .shader_id = cube_shader_id }) catch unreachable;
                m.addShaderPass(pine.ShaderPass{ .shader_id = lighting_shader_id }) catch unreachable;
            }

            var cube_node = self.scene.createNode(cube_label) catch unreachable;
            cube_node.mesh_id = cube_mesh_id;
            cube_node.material_id = cube_material_id;
            self.scene.root.addChild(cube_node) catch unreachable;

            cube_node_id = cube_node.id;
        }
    }

    export fn sokolFrameLitCubeExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            if (self.scene.getNodeByUID(cube_node_id)) |cube| {
                cube.transform.rotate(
                    pine.math.Vec3.with(0, 1, 1),
                    @floatCast(dt * 0.5),
                );
            }

            self.renderer.renderScene(&self.scene, &self.resource_manager);
        }
    }

    export fn sokolEventLitCubeExample(ev: [*c]const sokol.app.Event, world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            if (ev.*.key_code == .ESCAPE and ev.*.type == .KEY_UP) {
                sokol.app.requestQuit();
            }

            if (ev.*.key_code == .SPACE and ev.*.type == .KEY_UP) {
                if (self.scene.getNodeByUID(cube_node_id)) |cube| {
                    cube.visible = !cube.visible;
                }
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

    var world = WorldState.init(allocator) catch unreachable;
    defer world.deinit();

    world.run();
}
