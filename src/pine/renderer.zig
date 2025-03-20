const std = @import("std");
const sokol = @import("sokol");

const ResourceManager = @import("resource_manager.zig").ResourceManager;
const Camera = @import("camera.zig").Camera;
const Mesh = @import("mesh.zig").Mesh;
const Shader = @import("shader.zig").Shader;
const Material = @import("material.zig").Material;
const Transform = @import("transform.zig").Transform;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    render_queue: std.ArrayList(RenderCommand),
    camera: Camera,

    pub fn init(allocator: std.mem.Allocator) Renderer {
        const fov = 60;
        const aspect = sokol.app.widthf() / sokol.app.heightf();
        const near = 0.01;
        const far = 10;

        return .{
            .allocator = allocator,
            .render_queue = std.ArrayList(RenderCommand).init(allocator),
            .camera = Camera.init(fov, aspect, near, far),
        };
    }

    pub fn deinit(self: *const Renderer) void {
        self.render_queue.deinit();
    }

    pub fn render(self: *Renderer, resource_manager: *ResourceManager) void {
        self.camera.updateAspectRatio(sokol.app.widthf() / sokol.app.heightf());

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

        for (self.render_queue.items) |cmd| {
            self.executeRenderCommand(cmd, resource_manager);
        }

        sokol.gfx.endPass();
        sokol.gfx.commit();

        // ready the render queue for the next render call
        self.render_queue.clearRetainingCapacity();
    }

    pub fn addRenderCommand(self: *Renderer, cmd: RenderCommand) !void {
        try self.render_queue.append(cmd);
    }

    fn executeRenderCommand(self: *const Renderer, cmd: RenderCommand, resource_manager: *ResourceManager) void {
        if (resource_manager.getShader(cmd.material.shader_label)) |shader| {
            sokol.gfx.applyPipeline(shader.pipeline);
        }

        if (cmd.mesh) |mesh| {
            const bindings = blk: {
                var b = sokol.gfx.Bindings{};
                b.vertex_buffers[0] = mesh.vbuf;
                b.index_buffer = mesh.ibuf;
                break :blk b;
            };
            sokol.gfx.applyBindings(bindings);

            if (resource_manager.getTransform(cmd.material.transform_label)) |transform| {
                const mvp = Mat4.mul(self.camera.projection, Mat4.mul(
                    self.camera.view,
                    transform.get_model_matrix(),
                ));
                sokol.gfx.applyUniforms(0, sokol.gfx.asRange(&mvp));
            }

            sokol.gfx.draw(0, @intCast(mesh.indices.len), 1);
        }
    }
};

pub const RenderCommand = struct {
    mesh: ?*Mesh, // maybe we just want to paint with a shader
    transform: ?*Transform, // same as above
    material: *Material,
};
