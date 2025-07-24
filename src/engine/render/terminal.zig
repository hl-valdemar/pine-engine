const ecs = @import("pine-ecs");

pub const RenderTerminalPlugin = ecs.Plugin.init("render-terminal", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        try registry.addSystem("render.main", RenderSystem);
    }

    const RenderSystem = struct {
        pub fn process(self: *RenderSystem, registry: *ecs.Registry) anyerror!void {
            _ = self;
            _ = registry;
        }
    };
}.init);
