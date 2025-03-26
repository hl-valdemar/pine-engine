const std = @import("std");
const sokol = @import("sokol");
const pine = @import("pine");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

const cube = struct {
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
    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,
    camera: pine.Camera,
    renderer: pine.Renderer,

    pub fn init(allocator: std.mem.Allocator) WorldState {
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

            self.resource_manager.createMesh(cube.label, &cube.vertices, &cube.indices) catch |err| {
                std.log.err("failed to create cube mesh: {}", .{err});
                @panic("FAILED TO CREATE CUBE MESH!\n");
            };

            self.resource_manager.createShader(
                cube.label,
                @embedFile("shaders/cube.vs.metal"),
                @embedFile("shaders/cube.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create cube shader: {}", .{err});
                @panic("FAILED TO CREATE CUBE SHADER!\n");
            };

            self.resource_manager.createTransform(
                cube.label,
                pine.math.Vec3.zeros(),
                pine.math.Quaternion.identity(),
                pine.math.Vec3.ones(),
            ) catch |err| {
                std.log.err("failed to create cube transform: {}", .{err});
                @panic("FAILED TO CREATE CUBE TRANSFORM!\n");
            };

            self.resource_manager.createMaterial(cube.label, cube.label) catch |err| {
                std.log.err("failed to create cube material: {}", .{err});
                @panic("FAILED TO CREATE CUBE MATERIAL!\n");
            };
        }
    }

    export fn sokolFrameCubeExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            // apply rotation
            const transform = if (self.resource_manager.getTransform(cube.label)) |transform| blk: {
                transform.rotate(pine.math.Vec3.with(0, 1, 1), @floatCast(dt * 1));
                break :blk transform;
            } else blk: {
                break :blk null;
            };

            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh(cube.label),
                .transform = transform,
                .material = self.resource_manager.getMaterial(cube.label),
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };

            self.renderer.render(&self.resource_manager);
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

    var world = WorldState.init(allocator);
    defer world.deinit();

    world.run();
}
