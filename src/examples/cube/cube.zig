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
            .init_userdata_cb = sokolInit,
            .frame_userdata_cb = sokolFrame,
            .event_userdata_cb = sokolEvent,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Project: Pine",
        });
    }

    export fn sokolInit(game_state: ?*anyopaque) void {
        if (game_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

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
                @embedFile("shaders/cube.vs.metal"),
                @embedFile("shaders/cube.fs.metal"),
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

            self.resource_manager.createMaterial(label, label) catch |err| {
                std.log.err("failed to create test material: {}", .{err});
                @panic("FAILED TO CREATE TEST MATERIAL!\n");
            };
        }
    }

    export fn sokolFrame(game_state: ?*anyopaque) void {
        if (game_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            const mesh = if (self.resource_manager.getMesh("test")) |mesh| blk: {
                break :blk mesh;
            } else {
                @panic("FAILED TO FIND REQUIRED MESH!\n");
            };

            const transform = if (self.resource_manager.getTransform("test")) |transform| blk: {
                transform.rotation.angle += @floatCast(dt * 100);
                break :blk transform;
            } else {
                @panic("FAILED TO FIND REQUIRED TRANSFORM!\n");
            };

            const material = if (self.resource_manager.getMaterial("test")) |material| blk: {
                break :blk material;
            } else {
                @panic("FAILED TO FIND REQUIRED MATERIAL!\n");
            };

            self.renderer.addRenderCommand(.{
                .mesh = mesh,
                .transform = transform,
                .material = material,
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };

            self.renderer.render(&self.resource_manager);
        }
    }

    export fn sokolEvent(ev: [*c]const sokol.app.Event, game_state: ?*anyopaque) void {
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
