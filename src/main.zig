const std = @import("std");
const pine = @import("pine");
const sokol = @import("sokol");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

const WorldState = struct {
    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,

    pub fn init(allocator: std.mem.Allocator) WorldState {
        return .{
            .allocator = allocator,
            .resource_manager = pine.ResourceManager.init(allocator),
        };
    }

    pub fn deinit(self: *WorldState) void {
        self.resource_manager.deinit();
        self.allocator.destroy(self);
    }

    pub fn run(self: *WorldState) void {
        sokol.app.run(sokol.app.Desc{
            .init_userdata_cb = sokol_init,
            .frame_userdata_cb = sokol_frame,
            .event_userdata_cb = sokol_event,
            .cleanup_userdata_cb = sokol_cleanup,
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

            const vertices = [_]f32{ 0.23, 0, 23, 4 };
            const indices = [_]u16{ 2, 5, 6, 2, 2 };

            self.resource_manager.createMesh("test", &vertices, &indices) catch |err| {
                std.log.err("failed to create test mesh: {}", .{err});
            };
        }
    }

    export fn sokol_frame(game_state: ?*anyopaque) void {
        if (game_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));
            _ = self;

            // clear screen
            const pass = blk: {
                var p = sokol.gfx.Pass{ .swapchain = sokol.glue.swapchain() };
                p.action.colors[0] = .{
                    .load_action = .CLEAR,
                    .clear_value = .{
                        .r = 0,
                        .g = 0,
                        .b = 0,
                        .a = 1,
                    },
                };
                break :blk p;
            };
            sokol.gfx.beginPass(pass);

            // TODO: render stuff...

            sokol.gfx.endPass();
            sokol.gfx.commit();
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

    export fn sokol_cleanup(game_state: ?*anyopaque) void {
        if (game_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const r_back = self.resource_manager.getMesh("test");
            std.log.debug("r_back: {s}, vertices = {d}, indices = {d}\n", .{
                r_back.?.mesh.label,
                r_back.?.mesh.data.vertices,
                r_back.?.mesh.data.indices,
            });

            sokol.gfx.shutdown();
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
