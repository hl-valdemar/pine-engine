const plog = @import("../logging.zig").log;

const Renderer = @import("../renderer.zig").Renderer;
const ResourceManager = @import("../resource_manager.zig").ResourceManager;

const scene = @import("../scene.zig");
const SceneVisitor = scene.SceneVisitor;
const SceneNode = scene.SceneNode;

pub const LightCollector = struct {
    visitor: SceneVisitor,
    renderer: *Renderer,
    resource_manager: *ResourceManager,

    pub fn init(renderer: *Renderer, resource_manager: *ResourceManager) LightCollector {
        return .{
            .visitor = SceneVisitor.init(LightCollector),
            .renderer = renderer,
            .resource_manager = resource_manager,
        };
    }

    pub fn visitNode(self: *LightCollector, node: *SceneNode) void {
        if (node.light) |light| {
            const world_transform = node.getWorldTransform();
            switch (light.light_type) {
                .Directional => {
                    // transform direction by world rotation
                    // const world_dir = world_transform.rotation.rotateVec3(light.properties.direction);

                    const dir_light = light;
                    // dir_light.properties.direction = world_dir;

                    self.renderer.light_manager.directional_lights.append(.{
                        .node_id = node.id,
                        .light = dir_light,
                        .transform = world_transform,
                    }) catch |err| {
                        plog.err("failed to add directional light: {}", .{err});
                    };
                },
            }
        }
    }
};
