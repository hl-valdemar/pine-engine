const std = @import("std");
const sokol = @import("sokol");
const pine = @import("pine");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

const WorldState = struct {
    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,
    renderer: pine.Renderer,

    pub fn init(allocator: std.mem.Allocator) WorldState {
        return .{
            .allocator = allocator,
            .resource_manager = pine.ResourceManager.init(allocator),
            .renderer = pine.Renderer.init(allocator),
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
            .init_userdata_cb = sokol_init,
            .frame_userdata_cb = sokol_frame,
            .event_userdata_cb = sokol_event,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Project: Pine",
        });
    }

    export fn sokol_init(game_state: ?*anyopaque) void {
        if (game_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

            const vertices = [_]f32{
                // positions      colors
                -1.0, -1.0, -1.0, 1.0, 0.0, 0.0, 1.0,
                1.0,  -1.0, -1.0, 1.0, 0.0, 0.0, 1.0,
                1.0,  1.0,  -1.0, 1.0, 0.0, 0.0, 1.0,
                -1.0, 1.0,  -1.0, 1.0, 0.0, 0.0, 1.0,

                -1.0, -1.0, 1.0,  0.0, 1.0, 0.0, 1.0,
                1.0,  -1.0, 1.0,  0.0, 1.0, 0.0, 1.0,
                1.0,  1.0,  1.0,  0.0, 1.0, 0.0, 1.0,
                -1.0, 1.0,  1.0,  0.0, 1.0, 0.0, 1.0,

                -1.0, -1.0, -1.0, 0.0, 0.0, 1.0, 1.0,
                -1.0, 1.0,  -1.0, 0.0, 0.0, 1.0, 1.0,
                -1.0, 1.0,  1.0,  0.0, 0.0, 1.0, 1.0,
                -1.0, -1.0, 1.0,  0.0, 0.0, 1.0, 1.0,

                1.0,  -1.0, -1.0, 1.0, 0.5, 0.0, 1.0,
                1.0,  1.0,  -1.0, 1.0, 0.5, 0.0, 1.0,
                1.0,  1.0,  1.0,  1.0, 0.5, 0.0, 1.0,
                1.0,  -1.0, 1.0,  1.0, 0.5, 0.0, 1.0,

                -1.0, -1.0, -1.0, 0.0, 0.5, 1.0, 1.0,
                -1.0, -1.0, 1.0,  0.0, 0.5, 1.0, 1.0,
                1.0,  -1.0, 1.0,  0.0, 0.5, 1.0, 1.0,
                1.0,  -1.0, -1.0, 0.0, 0.5, 1.0, 1.0,

                -1.0, 1.0,  -1.0, 1.0, 0.0, 0.5, 1.0,
                -1.0, 1.0,  1.0,  1.0, 0.0, 0.5, 1.0,
                1.0,  1.0,  1.0,  1.0, 0.0, 0.5, 1.0,
                1.0,  1.0,  -1.0, 1.0, 0.0, 0.5, 1.0,
            };

            const indices = [_]u16{
                0,  1,  2,  0,  2,  3,
                6,  5,  4,  7,  6,  4,
                8,  9,  10, 8,  10, 11,
                14, 13, 12, 15, 14, 12,
                16, 17, 18, 16, 18, 19,
                22, 21, 20, 23, 22, 20,
            };

            const label = "test";

            self.resource_manager.createMesh(label, &vertices, &indices) catch |err| {
                std.log.err("failed to create test mesh: {}", .{err});
            };

            self.resource_manager.createShader(
                label,
                @embedFile("examples/cube/shaders/cube.vs.metal"),
                @embedFile("examples/cube/shaders/cube.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create test shader: {}", .{err});
            };

            self.resource_manager.createTransform(
                label,
                pine.math.Vec3.zeros(),
                .{},
                pine.math.Vec3.ones(),
            ) catch |err| {
                std.log.err("failed to create transform: {}", .{err});
                @panic("FAILED TO CREATE TRANSFORM!\n");
            };

            self.resource_manager.createMaterial(label, label, label) catch |err| {
                std.log.err("failed to create test material: {}", .{err});
                @panic("FAILED TO CREATE TEST MATERIAL!\n");
            };
        }
    }

    export fn sokol_frame(game_state: ?*anyopaque) void {
        if (game_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            const transform = self.resource_manager.getTransform("test");
            if (transform) |t| {
                t.rotation.angle += @floatCast(dt * 100.0);
            }

            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh("test"),
                .transform = self.resource_manager.getTransform("test"),
                .material = self.resource_manager.getMaterial("test").?,
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };

            self.renderer.render(&self.resource_manager);
        }
    }

    export fn sokol_event(ev: [*c]const sokol.app.Event, game_state: ?*anyopaque) void {
        if (game_state) |state| {
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
