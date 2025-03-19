const std = @import("std");
const sokol = @import("sokol");
const pine = @import("root.zig");
const cube_shd = @import("cube.glsl.zig");

pub const std_options = .{
    .logFn = pine.logging.log_fn,
};

// global instance pointer for sokol callbacks
var global_state_instance: ?*GameState = null;

const Font = enum {
    kc853,
    kc854,
};

const GameState = struct {
    allocator: std.mem.Allocator,
    resource_manager: pine.resource_manager.ResourceManager,
    renderer: pine.renderer.Renderer,

    var r: f32 = 0.0;

    // var cube_material: pine.material.Material = undefined;
    // var cube_mesh: pine.mesh.Mesh = undefined;

    const cube_vertices = [_]f32{
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

    const cube_indices = [_]u16{
        0,  1,  2,  0,  2,  3,
        6,  5,  4,  7,  6,  4,
        8,  9,  10, 8,  10, 11,
        14, 13, 12, 15, 14, 12,
        16, 17, 18, 16, 18, 19,
        22, 21, 20, 23, 22, 20,
    };

    var cube_mesh: pine.mesh.Mesh = undefined;
    var cube_material: pine.material.Material = undefined;
    var shader: sokol.gfx.Shader = undefined;

    const layout: sokol.gfx.VertexLayoutState = blk: {
        var l = sokol.gfx.VertexLayoutState{};
        l.attrs[cube_shd.ATTR_cube_position].format = .FLOAT3;
        l.attrs[cube_shd.ATTR_cube_color0].format = .FLOAT4;
        break :blk l;
    };

    var cube_transform = pine.renderer.Transform{};

    pub fn init(allocator: std.mem.Allocator) GameState {
        var state = GameState{
            .allocator = allocator,
            .resource_manager = pine.resource_manager.ResourceManager.init(allocator),
            .renderer = undefined, // must be intialized after sokol_init
        };
        global_state_instance = &state;
        return state;
    }

    pub fn deinit(self: *GameState) void {
        self.resource_manager.deinit();
        self.renderer.deinit();
        global_state_instance = null;
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

    pub fn on_sokol_init(self: *GameState) void {
        sokol.gfx.setup(.{
            .environment = sokol.glue.environment(),
            .logger = .{ .func = sokol.log.func },
        });

        std.log.debug("setting up cube mesh", .{});
        // cube_mesh = pine.mesh.Mesh.init(&cube_vertices, &cube_indices);
        self.resource_manager.addMesh("cube", &cube_vertices, &cube_indices) catch |err| {
            std.log.err("failed to create cube mesh: {}", .{err});
        };

        std.log.debug("setting up cube shader", .{});
        shader = sokol.gfx.makeShader(
            cube_shd.cubeShaderDesc(sokol.gfx.queryBackend()),
        );
        std.log.debug("setting up cube material", .{});
        cube_material = pine.material.Material.init(shader, layout);

        self.renderer = pine.renderer.Renderer.init(self.allocator);
    }

    pub fn on_sokol_frame(self: *GameState) void {
        const dt = sokol.app.frameDuration();
        r += @floatCast(dt * 200);

        cube_transform.rotation = .{
            .angle = r,
        };

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

        const cube_mesh_ptr = self.resource_manager.getMesh("cube") orelse {
            std.log.err("cube mesh not found", .{});
            sokol.gfx.endPass();
            sokol.gfx.commit();
            return;
        };

        sokol.gfx.applyPipeline(cube_material.pipeline);
        const bindings = blk: {
            var b = sokol.gfx.Bindings{};
            b.vertex_buffers[0] = cube_mesh_ptr.vbuf;
            b.index_buffer = cube_mesh_ptr.ibuf;
            break :blk b;
        };
        sokol.gfx.applyBindings(bindings);

        // setup shader uniforms
        const vs_params = pine.renderer.VsParams{
            .mvp = pine.math.Mat4.mul(
                self.renderer.camera.projection_matrix,
                pine.math.Mat4.mul(
                    self.renderer.camera.view_matrix,
                    cube_transform.get_model_matrix(),
                ),
            ),
        };

        sokol.gfx.applyUniforms(.VS, 0, sokol.gfx.asRange(&vs_params));
        sokol.gfx.draw(0, @intCast(cube_mesh.index_count), 1);

        sokol.gfx.endPass();
        sokol.gfx.commit();
    }

    pub fn on_sokol_event(self: *GameState, ev: *const sokol.app.Event) void {
        _ = self;
        if (ev.key_code == .ESCAPE and ev.type == .KEY_UP) {
            sokol.app.requestQuit();
        }
    }

    pub fn on_sokol_cleanup(self: *GameState) void {
        _ = self;
        sokol.gfx.shutdown();
    }
};

export fn sokol_init() void {
    if (global_state_instance) |state| {
        state.on_sokol_init();
    }
}

export fn sokol_frame() void {
    if (global_state_instance) |state| {
        state.on_sokol_frame();
    }
}

export fn sokol_event(ev: [*c]const sokol.app.Event) void {
    if (global_state_instance) |state| {
        state.on_sokol_event(ev);
    }
}

export fn sokol_cleanup() void {
    if (global_state_instance) |state| {
        state.on_sokol_cleanup();
    }
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("memory leak detected!\n", .{});
    }

    var state = GameState.init(allocator);
    defer state.deinit();

    state.run();
}
