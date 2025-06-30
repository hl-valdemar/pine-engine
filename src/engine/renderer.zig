const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pg = @import("pine-graphics");

const Schedule = @import("schedule.zig").Schedule;
const WindowComponent = @import("window.zig").WindowComponent;

pub const RenderPlugin = ecs.Plugin.init("renderer", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        try registry.registerTaggedSystem(RenderSystem, Schedule.Render.toString());
    }

    const RenderSystem = struct {
        var time: f32 = 0;

        clear_color: struct {
            r: f32 = 0.1,
            g: f32 = 0.2,
            b: f32 = 0.3,
            a: f32 = 1.0,
        },

        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{ .clear_color = .{} };
        }

        pub fn deinit(_: *RenderSystem) void {}

        pub fn process(self: *RenderSystem, registry: *ecs.Registry) anyerror!void {
            var window_entities = try registry.queryComponents(.{WindowComponent});

            // animate the clear color for visual feedback
            self.clear_color.r = @abs(@sin(time * 0.5)) * 0.3;
            self.clear_color.g = @abs(@sin(time * 0.3)) * 0.3;
            self.clear_color.b = @abs(@sin(time * 0.7)) * 0.3 + 0.2;
            time += 0.01;

            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;

                pg.beginPass(&window.handle, .{
                    .color = .{
                        .action = .clear,
                        .r = self.clear_color.r,
                        .g = self.clear_color.g,
                        .b = self.clear_color.b,
                        .a = self.clear_color.a,
                    },
                });

                // render logic here...

                pg.endPass(&window.handle);
                pg.commit(&window.handle);

                // rendering commands would go here
                // for example: draw meshes, sprites, etc.

                pg.endPass(&window.handle);
                pg.commit(&window.handle);
            }
        }
    };
}.init);
