const std = @import("std");
const sokol = @import("sokol");

const plog = @import("logging.zig").log;

const ResourceManager = @import("resource_manager.zig").ResourceManager;
const Camera = @import("camera.zig").Camera;
const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;
const Transform = @import("transform.zig").Transform;

const LightManager = @import("lighting/light_manager.zig").LightManager;
const LightCollector = @import("lighting/light_collector.zig").LightCollector;
const LightProperties = @import("lighting/light.zig").LightProperties;

const shd = @import("shader.zig");
const Shader = shd.Shader;
const VsParams = shd.VsParams;
const FsParams = shd.FsParams;

const sc = @import("scene.zig");
const Scene = sc.Scene;
const SceneNode = sc.SceneNode;
const SceneVisitor = sc.SceneVisitor;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4 = math.Mat4;

const UniqueID = @import("resource_manager.zig").UniqueID;

pub const UniformSlots = struct {
    pub const VS_PARAMS = 0;
    pub const FS_PARAMS = 1;
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    camera: Camera,
    render_queue: std.ArrayList(RenderCommand),
    light_manager: LightManager,

    pub fn init(allocator: std.mem.Allocator, camera: Camera) Renderer {
        return .{
            .allocator = allocator,
            .camera = camera,
            .render_queue = std.ArrayList(RenderCommand).init(allocator),
            .light_manager = LightManager.init(allocator),
        };
    }

    pub fn deinit(self: *const Renderer) void {
        self.render_queue.deinit();
        self.light_manager.deinit();
    }

    pub fn renderScene(
        self: *Renderer,
        scene: *Scene,
        resource_manager: *ResourceManager,
    ) void {
        self.camera.update();

        // clear and collect render commands from scene graph
        self.render_queue.clearRetainingCapacity();

        // first pass - collect lights
        var light_collector = LightCollector.init(self, resource_manager);
        scene.accept(&light_collector.visitor);

        // second pass - build render queue
        var render_visitor = RenderVisitor.init(self, resource_manager);
        const visibility_filter = struct {
            fn filter(node: *SceneNode) bool {
                return node.visible;
            }
        }.filter;
        scene.acceptFiltered(&render_visitor.visitor, visibility_filter);

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
    }

    pub fn addRenderCommand(self: *Renderer, cmd: RenderCommand) !void {
        try self.render_queue.append(cmd);
    }

    fn executeRenderCommand(
        self: *const Renderer,
        cmd: RenderCommand,
        resource_manager: *ResourceManager,
    ) void {
        const shader = if (resource_manager.getShader(cmd.material.shader_id)) |s| blk: {
            break :blk s;
        } else {
            plog.err("shader ID '{d}' not found", .{cmd.material.shader_id});
            return;
        };

        sokol.gfx.applyPipeline(shader.pipeline);
        sokol.gfx.applyBindings(cmd.mesh.bindings);

        const vs_params = VsParams{
            .model = cmd.transform.getModelMatrix(),
            .view = self.camera.view,
            .projection = self.camera.projection,
        };

        const light_entry = self.light_manager.directional_lights.getLastOrNull();
        const light_properties = if (light_entry) |entry| blk: {
            break :blk entry.light.properties;
        } else blk: {
            break :blk null;
        };

        const fs_params = FsParams{
            .light_properties = light_properties orelse LightProperties{},
            .camera_pos = self.camera.position,
        };

        sokol.gfx.applyUniforms(UniformSlots.VS_PARAMS, sokol.gfx.asRange(&vs_params));
        sokol.gfx.applyUniforms(UniformSlots.FS_PARAMS, sokol.gfx.asRange(&fs_params));

        const first_element = 0;
        const element_count: u32 = @intCast(cmd.mesh.indices.len);

        sokol.gfx.draw(first_element, element_count, cmd.instance_count);
    }
};

pub const RenderCommand = struct {
    mesh: *const Mesh,
    transform: Transform,
    material: *const Material,
    instance_count: u32 = 1,
    instance_data: ?[]const u8 = null,
};

const RenderVisitor = struct {
    visitor: SceneVisitor,
    renderer: *Renderer,
    resource_manager: *ResourceManager,

    pub fn init(renderer: *Renderer, resource_manager: *ResourceManager) RenderVisitor {
        return .{
            .visitor = SceneVisitor.init(RenderVisitor),
            .renderer = renderer,
            .resource_manager = resource_manager,
        };
    }

    pub fn visitNode(self: *RenderVisitor, node: *SceneNode) void {
        if (node.mesh_id != UniqueID.INVALID and node.material_id != UniqueID.INVALID) {
            const mesh = if (self.resource_manager.getMesh(node.mesh_id)) |m| blk: {
                break :blk m;
            } else {
                plog.err(
                    "mesh not found for node {s} with mesh_id {d}",
                    .{ node.label, node.mesh_id },
                );
                return;
            };

            const material = if (self.resource_manager.getMaterial(node.material_id)) |m| blk: {
                break :blk m;
            } else {
                plog.err(
                    "material not found for node {s} with material_id {d}",
                    .{ node.label, node.material_id },
                );
                return;
            };

            const cmd = RenderCommand{
                .mesh = mesh,
                .transform = node.getWorldTransform(),
                .material = material,
            };

            self.renderer.addRenderCommand(cmd) catch |err| {
                plog.err(
                    "failed to add render command for node {s}: {}",
                    .{ node.label, err },
                );
            };
        }
    }
};
