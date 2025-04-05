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

const light = @import("lighting/light.zig");
const LightType = light.LightType;
const LightProperties = light.LightProperties;

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

const UniqueID = @import("resource_manager.zig").UniqueId;

pub const AttributeSlots = struct {
    pub const POSITION = 0;
    pub const NORMALS = 1;
    pub const COLOR0 = 2;
    pub const TEXCOORD0 = 3;
};

pub const UniformSlots = struct {
    pub const VS_PARAMS = 0;
    pub const FS_PARAMS = 1;
};

const OFFSCREEN_SAMPLE_COUNT: usize = 1;

const PingPongBuffer = struct {
    color_img: sokol.gfx.Image,
    depth_img: sokol.gfx.Image,
};

pub const Renderer = struct {
    allocator: std.mem.Allocator,

    camera: Camera,
    render_queue: std.ArrayList(RenderCommand),
    light_manager: LightManager,

    num_shader_passes: usize = 0,
    ping_pong_buffers: [2]PingPongBuffer = undefined,

    current_frame_buffer: *PingPongBuffer = undefined,
    previous_frame_buffer: *PingPongBuffer = undefined,

    offscreen_pipeline_desc: sokol.gfx.PipelineDesc = .{},
    display_pipeline_desc: sokol.gfx.PipelineDesc = .{},
    sampler: sokol.gfx.Sampler = .{},

    pub fn init(allocator: std.mem.Allocator, camera: Camera) Renderer {
        return Renderer{
            .allocator = allocator,
            .camera = camera,
            .render_queue = std.ArrayList(RenderCommand).init(allocator),
            .light_manager = LightManager.init(allocator),
        };
    }

    // all sokol related initializations
    pub fn initAfterSokol(self: *Renderer) void {
        self.setupPipelineDesc();
        self.setupRenderTargets();
        self.setupSamplers();
    }

    pub fn deinit(self: *Renderer) void {
        self.render_queue.deinit();
        self.light_manager.deinit();

        for (self.ping_pong_buffers) |entry| {
            sokol.gfx.destroyImage(entry.color_img);
            sokol.gfx.destroyImage(entry.depth_img);
        }

        sokol.gfx.destroySampler(self.sampler);
    }

    fn setupPipelineDesc(self: *Renderer) void {
        const offscreen_pipeline_layout: sokol.gfx.VertexLayoutState = blk: {
            var l = sokol.gfx.VertexLayoutState{};

            l.attrs[AttributeSlots.POSITION].format = .FLOAT3;
            l.attrs[AttributeSlots.POSITION].buffer_index = 0;

            l.attrs[AttributeSlots.NORMALS].format = .FLOAT3;
            l.attrs[AttributeSlots.NORMALS].buffer_index = 1;

            l.attrs[AttributeSlots.COLOR0].format = .FLOAT4;
            l.attrs[AttributeSlots.COLOR0].buffer_index = 2;

            break :blk l;
        };

        const display_pipeline_layout: sokol.gfx.VertexLayoutState = blk: {
            var l = sokol.gfx.VertexLayoutState{};

            l.attrs[AttributeSlots.POSITION].format = .FLOAT3;
            l.attrs[AttributeSlots.POSITION].buffer_index = 0;

            l.attrs[AttributeSlots.NORMALS].format = .FLOAT3;
            l.attrs[AttributeSlots.NORMALS].buffer_index = 1;

            l.attrs[AttributeSlots.COLOR0].format = .FLOAT4;
            l.attrs[AttributeSlots.COLOR0].buffer_index = 2;

            break :blk l;
        };

        self.offscreen_pipeline_desc = blk: {
            var p = sokol.gfx.PipelineDesc{
                .label = "offscreen-pipeline",
                .layout = offscreen_pipeline_layout,
                .index_type = .UINT32,
                .cull_mode = .NONE,
                .face_winding = .CW,
                .sample_count = OFFSCREEN_SAMPLE_COUNT,
                .depth = .{
                    .pixel_format = .DEPTH,
                    .compare = .LESS_EQUAL,
                    .write_enabled = true,
                },
            };

            p.colors[0].pixel_format = .RGBA8;

            // enable transparency between shader passes
            p.colors[0].blend.enabled = true;
            p.colors[0].blend.src_factor_rgb = .SRC_ALPHA;
            p.colors[0].blend.dst_factor_rgb = .ONE_MINUS_SRC_ALPHA;
            p.colors[0].blend.src_factor_alpha = .ONE;
            p.colors[0].blend.dst_factor_alpha = .ONE_MINUS_SRC_ALPHA;

            break :blk p;
        };

        self.display_pipeline_desc = blk: {
            var p = sokol.gfx.PipelineDesc{
                .label = "default-pipeline",
                .layout = display_pipeline_layout,
                .index_type = .UINT32,
                .cull_mode = .NONE,
                .face_winding = .CW,
                .depth = .{
                    .compare = .LESS_EQUAL,
                    .write_enabled = true,
                },
            };

            // p.colors[0].pixel_format = .RGBA8;

            // enable transparency between shader passes
            p.colors[0].blend.enabled = true;
            p.colors[0].blend.src_factor_rgb = .SRC_ALPHA;
            p.colors[0].blend.dst_factor_rgb = .ONE_MINUS_SRC_ALPHA;
            p.colors[0].blend.src_factor_alpha = .ONE;
            p.colors[0].blend.dst_factor_alpha = .ONE_MINUS_SRC_ALPHA;

            break :blk p;
        };
    }

    fn setupRenderTargets(self: *Renderer) void {
        const color_img_desc = sokol.gfx.ImageDesc{
            .render_target = true,
            .width = sokol.app.width(),
            .height = sokol.app.height(),
            .pixel_format = .RGBA8,
            .sample_count = OFFSCREEN_SAMPLE_COUNT,
            .label = "color-image",
        };

        const depth_img_desc = sokol.gfx.ImageDesc{
            .render_target = true,
            .width = sokol.app.width(),
            .height = sokol.app.height(),
            .pixel_format = .DEPTH,
            .sample_count = OFFSCREEN_SAMPLE_COUNT,
            .label = "depth-image",
        };

        self.ping_pong_buffers[0] = .{
            .color_img = sokol.gfx.makeImage(color_img_desc),
            .depth_img = sokol.gfx.makeImage(depth_img_desc),
        };
        self.ping_pong_buffers[1] = .{
            .color_img = sokol.gfx.makeImage(color_img_desc),
            .depth_img = sokol.gfx.makeImage(depth_img_desc),
        };

        self.current_frame_buffer = &self.ping_pong_buffers[0];
        self.previous_frame_buffer = &self.ping_pong_buffers[1];
    }

    fn setupSamplers(self: *Renderer) void {
        const sampler_desc = sokol.gfx.SamplerDesc{
            .min_filter = .LINEAR,
            .mag_filter = .LINEAR,
            .wrap_u = .REPEAT,
            .wrap_v = .REPEAT,
            .label = "texture-sampler",
        };

        self.sampler = sokol.gfx.makeSampler(sampler_desc);
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
        defer self.num_shader_passes = 0; // reset the counter at the end of the render pass

        for (self.render_queue.items) |cmd| {
            self.executeRenderCommand(cmd, resource_manager);
        }

        sokol.gfx.commit();
    }

    pub fn addRenderCommand(self: *Renderer, cmd: RenderCommand) !void {
        try self.render_queue.append(cmd);
    }

    fn computePass(self: *const Renderer, is_final_pass: bool) sokol.gfx.Pass {
        var render_pass = sokol.gfx.Pass{};

        // check for final pass
        if (is_final_pass) {
            render_pass.action.colors[0] = .{
                .load_action = .CLEAR,
                .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
            };
            render_pass.action.depth = .{
                .load_action = .CLEAR,
                .clear_value = 1,
            };
            render_pass.swapchain = sokol.glue.swapchain(); // render to screen
            render_pass.label = "swapchain-pass";

            return render_pass;
        }

        // else intermediate pass
        var attachment_desc = sokol.gfx.AttachmentsDesc{};
        attachment_desc.colors[0].image = self.current_frame_buffer.color_img;
        attachment_desc.depth_stencil.image = self.current_frame_buffer.depth_img;
        attachment_desc.label = "offscreen-attachments";

        render_pass.action.colors[0] = .{
            .load_action = .LOAD,
            .store_action = .STORE,
        };
        render_pass.action.depth = .{
            .load_action = .LOAD,
            .store_action = .STORE,
        };

        render_pass.attachments = sokol.gfx.makeAttachments(attachment_desc);
        render_pass.label = "offscreen-pass";

        return render_pass;
    }

    fn computePipeline(self: *const Renderer, is_final_pass: bool, shader: *const Shader) sokol.gfx.Pipeline {
        const pipeline_desc = if (is_final_pass) blk: {
            var pipeline_desc = self.display_pipeline_desc;
            pipeline_desc.shader = shader.shader;
            break :blk pipeline_desc;
        } else blk: {
            var pipeline_desc = self.offscreen_pipeline_desc;
            pipeline_desc.shader = shader.shader;
            break :blk pipeline_desc;
        };

        return sokol.gfx.makePipeline(pipeline_desc);
    }

    fn swapTargetBuffers(self: *Renderer) void {
        const current_frame_buffer_tmp = self.current_frame_buffer;
        self.current_frame_buffer = self.previous_frame_buffer;
        self.previous_frame_buffer = current_frame_buffer_tmp;
    }

    fn executeRenderCommand(
        self: *Renderer,
        cmd: RenderCommand,
        resource_manager: *ResourceManager,
    ) void {
        for (cmd.material.shader_passes.items, 0..) |shader_pass, i| {
            const is_final_pass = i == self.num_shader_passes - 1;

            // compute pass to use
            const pass = self.computePass(is_final_pass);
            sokol.gfx.beginPass(pass);

            // compute pipeline to use
            const shader = resource_manager.getShader(shader_pass.shader_id) orelse {
                plog.err("shader ID '{d}' not found", .{shader_pass.shader_id});
                return;
            };
            const pipeline = self.computePipeline(is_final_pass, shader);
            defer sokol.gfx.destroyPipeline(pipeline);
            sokol.gfx.applyPipeline(pipeline);

            // attach previous result
            var bindings = cmd.mesh.bindings;
            bindings.images[0] = self.previous_frame_buffer.color_img;
            bindings.samplers[0] = self.sampler;
            sokol.gfx.applyBindings(bindings);

            const vs_params = VsParams{
                .model = cmd.transform.getModelMatrix(),
                .view = self.camera.view,
                .projection = self.camera.projection,
            };

            // const light_entry = self.light_manager.directional_lights.getLastOrNull();
            // const light_properties = if (light_entry) |entry| blk: {
            //     break :blk entry.light.properties;
            // } else blk: {
            //     break :blk null;
            // };
            const light_entry = self.light_manager.point_lights.getLastOrNull();
            const light_type = if (light_entry) |entry| blk: {
                break :blk entry.light.light_type;
            } else blk: {
                break :blk null;
            };
            const light_properties = if (light_entry) |entry| blk: {
                break :blk entry.light.properties;
            } else blk: {
                break :blk null;
            };

            const fs_params = FsParams{
                .light_type = light_type orelse LightType.Directional,
                .light_properties = light_properties orelse LightProperties{},
                .camera_pos = self.camera.position,
            };

            sokol.gfx.applyUniforms(UniformSlots.VS_PARAMS, sokol.gfx.asRange(&vs_params));
            sokol.gfx.applyUniforms(UniformSlots.FS_PARAMS, sokol.gfx.asRange(&fs_params));

            const first_element = 0;
            const element_count: u32 = @intCast(cmd.mesh.indices.len);
            sokol.gfx.draw(first_element, element_count, cmd.instance_count);

            sokol.gfx.endPass();

            sokol.gfx.destroyAttachments(pass.attachments);

            // remember to swap buffers!
            self.swapTargetBuffers();
        }
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

            // count the number of shader passes
            self.renderer.num_shader_passes += material.shader_passes.items.len;

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
