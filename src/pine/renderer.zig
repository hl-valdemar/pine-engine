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

pub const UniformSlots = struct {
    pub const MODEL_VIEW_PROJECTION = 0;
};

const RenderError = error{
    MissingMesh,
    MissingTransform,
    MissingMaterial,
    MissingShader,
};

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
        self.camera.update();

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

        // execute render commands and handle potential errors
        for (self.render_queue.items) |cmd| {
            self.executeRenderCommand(cmd, resource_manager) catch |err| {
                std.log.err("failed to execute render command: {}", .{err});
                switch (err) {
                    RenderError.MissingMesh => std.log.err("mesh not found", .{}),
                    RenderError.MissingTransform => std.log.err("transform not found", .{}),
                    RenderError.MissingMaterial => std.log.err("material not found", .{}),
                    RenderError.MissingShader => {
                        if (cmd.material) |material| {
                            std.log.err("shader '{s}' not found", .{material.shader_label});
                        } else {
                            std.log.err("shader not found", .{});
                        }
                    },
                }
            };
        }

        sokol.gfx.endPass();
        sokol.gfx.commit();

        // ready the render queue for the next render call
        self.render_queue.clearRetainingCapacity();
    }

    pub fn addRenderCommand(self: *Renderer, cmd: RenderCommand) !void {
        try self.render_queue.append(cmd);
    }

    fn executeRenderCommand(
        self: *const Renderer,
        cmd: RenderCommand,
        resource_manager: *ResourceManager,
    ) RenderError!void {
        const mesh = cmd.mesh orelse
            return RenderError.MissingMesh;

        const transform = cmd.transform orelse
            return RenderError.MissingTransform;

        const material = cmd.material orelse
            return RenderError.MissingMaterial;

        const shader = resource_manager.getShader(material.shader_label) orelse
            return RenderError.MissingShader;

        sokol.gfx.applyPipeline(shader.pipeline);
        sokol.gfx.applyBindings(mesh.bindings);

        const mvp = self.camera.computeMVP(transform);

        sokol.gfx.applyUniforms(UniformSlots.MODEL_VIEW_PROJECTION, sokol.gfx.asRange(&mvp));

        const first_element = 0;
        const element_count: u32 = @intCast(mesh.indices.len);

        sokol.gfx.draw(first_element, element_count, cmd.instance_count);
    }
};

pub const RenderCommand = struct {
    mesh: ?*Mesh,
    transform: ?*Transform,
    material: ?*Material,
    instance_count: u32 = 1,
    instance_data: ?[]const u8 = null,
};
