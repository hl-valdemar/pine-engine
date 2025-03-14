const std = @import("std");
const sokol = @import("sokol");

const sc = @import("scene.zig");
const Scene = sc.Scene;
const SceneNode = sc.SceneNode;
const Transform = sc.Transform;

const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;
const Camera = @import("camera.zig").Camera;

const utils = @import("utils.zig");
const Mat4 = utils.Mat4;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    scene: *Scene,
    camera: Camera,
    render_queue: std.ArrayList(RenderCommand),

    pub fn init(allocator: std.mem.Allocator, scene: *Scene) Renderer {
        return .{
            .allocator = allocator,
            .scene = scene,
            .camera = Camera.create_perspective(60, 16 / 9, 0.1, 100),
            .render_queue = std.ArrayList(RenderCommand).init(allocator),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.scene.deinit();
        self.render_queue.deinit();
    }

    pub fn render(self: *Renderer) void {
        // Clear the render queue
        self.render_queue.clearRetainingCapacity();

        // Update scene transforms
        self.scene.update();

        // Collect render commands
        self.collect_render_commands(self.scene.root);

        // Begin sokol render pass
        var pass = sokol.gfx.Pass{};
        pass.action.colors[0] = .{
            .load_action = .CLEAR,
            .clear_value = .{ .r = 0.1, .g = 0.1, .b = 0.2, .a = 1.0 },
        };
        pass.swapchain = sokol.glue.swapchain();
        sokol.gfx.beginPass(pass);

        // Execute render commands
        for (self.render_queue.items) |cmd| {
            self.execute_render_command(cmd);
        }

        // End render pass and commit
        sokol.gfx.endPass();
        sokol.gfx.commit();
    }

    fn collect_render_commands(self: *Renderer, node: *SceneNode) void {
        // if node has a mesh and material, add a render command
        if (node.mesh != null and node.material != null) {
            self.render_queue.append(.{
                .mesh = node.mesh.?,
                .material = node.material.?,
                .transform = node.transform,
            }) catch unreachable;
        }

        // process children
        for (node.children.items) |child| {
            self.collect_render_commands(child);
        }
    }

    fn execute_render_command(self: *Renderer, cmd: RenderCommand) void {
        // apply shader and pipeline
        sokol.gfx.applyPipeline(cmd.material.pipeline);

        // update uniforms
        var vs_params = VsParams{
            .model = cmd.transform.world_matrix,
            .view = self.camera.view_matrix,
            .projection = self.camera.projection_matrix,
        };

        // apply uniforms
        sokol.gfx.applyUniforms(.VS, 0, sokol.gfx.asRange(&vs_params));

        // bind vertex and index buffers
        var bindings = sokol.gfx.Bindings{};
        bindings.vertex_buffers[0] = cmd.mesh.vbuf;
        bindings.index_buffer = cmd.mesh.ibuf;

        sokol.gfx.applyBindings(bindings);

        // draw
        sokol.gfx.draw(0, @intCast(cmd.mesh.indices.len), 1);
    }
};

const RenderCommand = struct {
    mesh: *Mesh,
    material: *Material,
    transform: Transform,

    fn less_than(_: void, left: RenderCommand, right: RenderCommand) bool {
        _ = left;
        _ = right;
        @panic("NOT IMPLEMENTED!\n");
    }
};

pub const VsParams = extern struct {
    model: Mat4 align(16),
    view: Mat4 align(16),
    projection: Mat4 align(16),
};
