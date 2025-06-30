const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pg = @import("pine-graphics");

const Schedule = @import("schedule.zig").Schedule;
const WindowComponent = @import("window.zig").WindowComponent;

pub const RenderTargetComponent = struct {};

pub const RenderPlugin = ecs.Plugin.init("renderer", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        try registry.registerTaggedSystem(RenderSystem, Schedule.Render.toString());
    }

    const RenderSystem = struct {
        context: pg.GraphicsContext,
        frame_count: u64,

        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{
                .context = try pg.GraphicsContext.create(.auto),
                .frame_count = 0,
            };
        }

        pub fn deinit(_: *RenderSystem) void {}

        pub fn process(self: *RenderSystem, registry: *ecs.Registry) anyerror!void {
            var window_entities = try registry.queryComponents(.{ WindowComponent, RenderTargetComponent });
            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;

                // create the swapchain
                var swapchain = try pg.Swapchain.create(&self.context, &window.handle);

                // begin render pass
                var render_pass = try pg.beginPass(&swapchain, .{
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
                pg.present(&swapchain);

                self.frame_count += 1;
                std.time.sleep(16 * std.time.ns_per_ms); // ~60 fps
            }
        }
    };
}.init);
