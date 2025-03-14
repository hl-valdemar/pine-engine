const std = @import("std");
const sokol = @import("sokol");
const pine = @import("root.zig");

pub const std_options = .{
    .logFn = pine.logging.log,
};

// global instance pointer for sokol callbacks
var global_game_instance: ?*GameState = null;

const Font = enum {
    kc853,
    kc854,
};

const GameState = struct {
    allocator: std.mem.Allocator,
    renderer: pine.renderer.Renderer,
    pass_action: sokol.gfx.PassAction,

    pub fn init(allocator: std.mem.Allocator) !*GameState {
        const game = try allocator.create(GameState);
        var scene = try pine.scene.Scene.init(allocator);

        game.* = .{
            .allocator = allocator,
            .renderer = pine.renderer.Renderer.init(allocator, &scene),
            .pass_action = .{},
        };

        game.*.pass_action.colors[0] = .{
            .load_action = .CLEAR,
            .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        };

        global_game_instance = game;
        return game;
    }

    pub fn deinit(self: *GameState) void {
        self.renderer.deinit();
        self.allocator.destroy(self);
        global_game_instance = null;
    }

    pub fn run(self: *GameState) void {
        _ = self;
        sokol.app.run(.{
            .init_cb = sokol_init,
            .frame_cb = sokol_frame,
            .event_cb = sokol_event,
            .cleanup_cb = sokol_cleanup,
            .width = 4 * 300,
            .height = 3 * 300,
            .sample_count = 4,
            .icon = .{ .sokol_default = true },
            .window_title = "Project: Pine",
            .logger = .{ .func = sokol.log.func },
        });
    }

    fn on_init(self: *GameState) void {
        // Create triangle mesh
        const triangle = pine.mesh.Mesh.create_triangle_mesh(self.allocator) catch {
            std.log.err("Failed to create triangle mesh", .{});
            return;
        };

        // Create basic shader and material
        const shader = pine.material.Material.create_basic_shader();
        var material = pine.material.Material.init(shader, pine.mesh.Vertex.get_vertex_layout());

        // Add to scene
        var triangle_node = pine.scene.SceneNode.init(self.allocator, "triangle") catch {
            std.log.err("Failed to create triangle node", .{});
            return;
        };
        self.renderer.scene.root.add_child(triangle_node);

        triangle_node.mesh = triangle;
        triangle_node.material = &material;

        // Position slightly in front of camera
        triangle_node.transform.position = .{ .x = 0, .y = 0, .z = -5 };

        self.renderer.scene.root.add_child(triangle_node);

        // Set up camera
        self.renderer.camera = pine.camera.Camera.create_perspective(
            std.math.degreesToRadians(60.0),
            sokol.app.widthf() / sokol.app.heightf(),
            0.1,
            100.0,
        );
    }

    fn on_frame(self: *GameState) void {
        const dt = sokol.app.frameDuration();

        // TODO: update scene/camera

        self.renderer.render();

        // debug text
        sokol.debugtext.canvas(
            sokol.app.widthf() * 0.5,
            sokol.app.heightf() * 0.5,
        );
        sokol.debugtext.origin(1, 1);

        sokol.debugtext.font(@intFromEnum(Font.kc854));
        sokol.debugtext.color3b(255, 255, 255);
        sokol.debugtext.print(
            "Frame Time: {d:.3}ms ({d:.3} FPS)\n",
            .{ dt, 1 / dt },
        );

        // begin render pass
        sokol.gfx.beginPass(.{
            .action = self.pass_action,
            .swapchain = sokol.glue.swapchain(),
        });

        sokol.debugtext.draw();

        sokol.gfx.endPass();
        sokol.gfx.commit();
    }

    fn on_event(self: *GameState, ev: *const sokol.app.Event) void {
        _ = self;
        const should_quit = ev.key_code == sokol.app.Keycode.ESCAPE and ev.type == sokol.app.EventType.KEY_UP;
        if (should_quit) {
            sokol.app.requestQuit();
        }
    }
};

export fn sokol_init() void {
    sokol.gfx.setup(.{
        .environment = sokol.glue.environment(),
        .logger = .{ .func = sokol.log.func },
    });

    // setup debug fonts
    sokol.debugtext.setup(.{
        .fonts = font_init: {
            var f: [8]sokol.debugtext.FontDesc = undefined;
            for (&f) |*font| {
                font.* = .{};
            }
            f[@intFromEnum(Font.kc853)] = sokol.debugtext.fontKc853();
            f[@intFromEnum(Font.kc854)] = sokol.debugtext.fontKc854();
            break :font_init f;
        },
        .logger = .{ .func = sokol.log.func },
    });

    if (global_game_instance) |game| {
        game.on_init();
    }

    std.log.info("initialized pine engine", .{});
}

export fn sokol_frame() void {
    if (global_game_instance) |game| {
        game.on_frame();
    }
}

export fn sokol_event(ev: [*c]const sokol.app.Event) void {
    if (global_game_instance) |game| {
        game.on_event(ev);
    }
}

export fn sokol_cleanup() void {
    if (global_game_instance) |game| {
        // game cleanup stuff
        _ = game;
    }

    sokol.debugtext.shutdown();
    sokol.gfx.shutdown();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("memory leak detected!\n", .{});
    }

    const game = try GameState.init(allocator);
    defer game.deinit();

    game.run();
}
