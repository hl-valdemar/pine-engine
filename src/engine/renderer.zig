const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pg = @import("pine-graphics");

const Schedule = @import("schedule.zig").Schedule;
const WindowComponent = @import("window.zig").WindowComponent;

pub const RenderTarget = struct {
    context: pg.GraphicsContext,
    swapchain: pg.Swapchain,
};

pub const RenderPlugin = ecs.Plugin.init("renderer", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        try registry.registerTaggedSystem(RenderSystem, Schedule.Render.toString());
        try registry.registerTaggedSystem(CleanupSystem, Schedule.Deinit.toString());
    }

    const RenderSystem = struct {
        frame_count: u64,

        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{ .frame_count = 0 };
        }

        pub fn deinit(_: *RenderSystem) void {}

        pub fn process(self: *RenderSystem, registry: *ecs.Registry) anyerror!void {
            var window_entities = try registry.queryComponents(.{RenderTarget});
            while (window_entities.next()) |entity| {
                const target = entity.get(RenderTarget).?;

                // begin render pass
                var render_pass = try pg.beginPass(&target.swapchain, .{
                    .color = .{
                        .action = .clear,
                        .r = @sin(@as(f32, @floatFromInt(self.frame_count)) * 0.01) * 0.5 + 0.5,
                        .g = 0.3,
                        .b = 0.3,
                        .a = 1.0,
                    },
                });

                // render commands would go here...

                // end render pass
                render_pass.end();

                // present the frame
                pg.present(&target.swapchain);

                self.frame_count += 1;
                std.time.sleep(16 * std.time.ns_per_ms); // ~60 fps
            }
        }
    };

    const CleanupSystem = struct {
        pub fn init(_: Allocator) anyerror!CleanupSystem {
            return CleanupSystem{};
        }

        pub fn deinit(_: *CleanupSystem) void {}

        pub fn process(_: *CleanupSystem, registry: *ecs.Registry) anyerror!void {
            var render_targets = try registry.queryComponents(.{RenderTarget});
            while (render_targets.next()) |entity| {
                const target = entity.get(RenderTarget).?;
                target.context.destroy();
                target.swapchain.destroy();
            }
        }
    };
}.init);
