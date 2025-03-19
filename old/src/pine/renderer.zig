const std = @import("std");
const sokol = @import("sokol");

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;
const Camera = @import("camera.zig").Camera;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    camera: Camera,
    render_queue: std.ArrayList(RenderCommand),

    pub fn init(allocator: std.mem.Allocator) Renderer {
        const position = Vec3.init(0, 1.5, 10);
        const target = Vec3.zero();
        const up = Vec3.up();
        const fov = 60;
        const aspect = sokol.app.widthf() / sokol.app.heightf();
        const near = 0.01;
        const far = 100;

        return .{
            .allocator = allocator,
            .camera = Camera.init(position, target, up, fov, aspect, near, far),
            .render_queue = std.ArrayList(RenderCommand).init(allocator),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.render_queue.deinit();
    }

    pub fn render(self: *Renderer) void {
        std.log.info("rendering...", .{});

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

        // execute render commands
        for (self.render_queue.items) |cmd| {
            self.execute_render_command(cmd);
        }

        sokol.gfx.endPass();
        sokol.gfx.commit();

        // clear the render queue for the next pass
        self.render_queue.clearRetainingCapacity();
    }

    pub fn add_render_command(self: *Renderer, cmd: *const RenderCommand) !void {
        std.log.info("appending render command", .{});
        try self.render_queue.append(RenderCommand{
            .mesh = cmd.mesh,
            .material = cmd.material,
            .transform = cmd.transform,
        });
        std.log.info("render command appended", .{});
    }

    fn execute_render_command(self: *Renderer, cmd: RenderCommand) void {
        std.log.info("executing render command", .{});

        sokol.gfx.applyPipeline(cmd.material.pipeline);
        const bindings = blk: {
            var b = sokol.gfx.Bindings{};
            b.vertex_buffers[0] = cmd.mesh.vbuf;
            b.index_buffer = cmd.mesh.ibuf;
            break :blk b;
        };
        sokol.gfx.applyBindings(bindings);

        // setup shader uniforms
        const vs_params = VsParams{
            .mvp = Mat4.mul(
                self.camera.projection_matrix,
                Mat4.mul(
                    self.camera.view_matrix,
                    cmd.transform.get_model_matrix(),
                ),
            ),
        };

        sokol.gfx.applyUniforms(.VS, 0, sokol.gfx.asRange(&vs_params));
        sokol.gfx.draw(0, @intCast(cmd.mesh.index_count), 1);
    }

    // // TEMPORARY SIMPLIFIED RENDER FUNCTION FOR TESTING
    // pub fn render_cube(
    //     self: *Renderer,
    //     mesh: Mesh,
    //     material: Material,
    // ) void {
    //     // clear screen
    //     const pass = blk: {
    //         var p = sokol.gfx.Pass{ .swapchain = sokol.glue.swapchain() };
    //         p.action.colors[0] = .{
    //             .load_action = .CLEAR,
    //             .clear_value = .{
    //                 .r = 0,
    //                 .g = 0,
    //                 .b = 0,
    //                 .a = 1,
    //             },
    //         };
    //         break :blk p;
    //     };
    //     sokol.gfx.beginPass(pass);
    //
    //     // use the same rotation logic from the working code
    //     const dt: f32 = @floatCast(sokol.app.frameDuration() * 60);
    //     GameState.r += 1.0 / 30.0 * dt;
    //
    //     // setup transform
    //     const transform = Transform{
    //         .position = Vec3.init(
    //             @cos(GameState.r),
    //             0,
    //             @sin(GameState.r),
    //         ),
    //         .rotation = .{
    //             .angle = GameState.r * 25,
    //             .axis_norm = Vec3.init(-1, 0, -1),
    //         },
    //     };
    //
    //     // setup shader uniforms
    //     const vs_params = cube_shd.VsParams{
    //         .mvp =Mat4.mul(
    //             self.camera.projection_matrix,
    //             Mat4.mul(
    //                 self.camera.view_matrix,
    //                 transform.get_model_matrix(),
    //             ),
    //         ),
    //     };
    //
    //     // draw
    //     sokol.gfx.applyPipeline(material.pipeline);
    //     const bindings = blk: {
    //         var b = sokol.gfx.Bindings{};
    //         b.vertex_buffers[0] = mesh.vbuf;
    //         b.index_buffer = mesh.ibuf;
    //         break :blk b;
    //     };
    //     sokol.gfx.applyBindings(bindings);
    //
    //     sokol.gfx.applyUniforms(.VS, cube_shd.UB_vs_params, sokol.gfx.asRange(&vs_params));
    //     sokol.gfx.draw(0, 36, 1);
    //
    //     sokol.gfx.endPass();
    //     sokol.gfx.commit();
    // }
};

pub const Transform = struct {
    position: Vec3 = Vec3.zero(),
    // TODO: use quaternions for rotations instead of matrices
    rotation: struct {
        angle: f32 = 0,
        axis_norm: Vec3 = Vec3.init(0, 1, 0),
    } = .{},
    scale: Vec3 = Vec3.init(1, 1, 1),

    pub fn get_model_matrix(self: Transform) Mat4 {
        const T = Mat4.translate(self.position);
        const R = Mat4.rotate(self.rotation.angle, self.rotation.axis_norm);
        const S = Mat4.scale(self.scale);
        return Mat4.mul(T, Mat4.mul(R, S));
    }
};

pub const RenderCommand = struct {
    mesh: Mesh,
    material: Material,
    transform: Transform,
};

pub const VsParams = extern struct {
    mvp: Mat4 align(16),
};
