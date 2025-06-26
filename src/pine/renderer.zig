const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @cImport(@cInclude("GLFW/glfw3.h"));
const pecs = @import("pecs");
const sokol = @import("sokol");
const gfx = sokol.gfx;

const Schedule = @import("schedule.zig").Schedule;
const WindowComponent = @import("window.zig").WindowComponent;

const RendererPlugin = pecs.Plugin.init("renderer", struct {
    fn init(registry: *pecs.Registry) anyerror!void {
        try registry.registerTaggedSystem(RendererInitSystem, Schedule.Init.toString());
    }

    const RendererInitSystem = struct {
        pub fn init(_: Allocator) anyerror!RendererInitSystem {
            return RendererInitSystem{};
        }

        pub fn deinit(_: *RendererInitSystem) void {
            gfx.shutdown();
        }

        pub fn process(_: *RendererInitSystem, _: *pecs.Registry) anyerror!void {
            sokol.gfx.setup(sokol.gfx.Desc{
                .environment = glfwEnvironment(),
            });
        }

        fn glfwEnvironment() gfx.Environment {
            return gfx.Environment{
                .defaults = .{
                    .color_format = gfx.PixelFormat.RGBA8,
                    .depth_format = gfx.PixelFormat.DEPTH_STENCIL,
                    .sample_count = 4,
                },
            };
        }
    };

    const RenderSystem = struct {
        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{};
        }

        pub fn deinit(_: *RenderSystem) void {}

        pub fn process(_: *RenderSystem, registry: *pecs.Registry) anyerror!void {
            var window_entities = try registry.queryComponents(.{WindowComponent});
            while (window_entities.next()) |entity| {
                var pass_action = gfx.PassAction{};
                pass_action.colors[0] = gfx.ColorAttachmentAction{
                    .load_action = gfx.LoadAction.CLEAR,
                    .clear_value = .{
                        .r = 0.0,
                        .g = 0.0,
                        .b = 0.0,
                        .a = 1.0,
                    },
                };

                gfx.beginPass(.{
                    .action = pass_action,
                    .swapchain = glfwSwapchain(),
                });
                gfx.endPass();
                gfx.commit();

                const window = entity.get(WindowComponent).?;
                c.glfwSwapBuffers(window.handle);
            }
        }

        fn glfwSwapchain(window_handle: c.GLFWWindow) gfx.Swapchain {
            var width: c_int = undefined;
            var height: c_int = undefined;
            c.glfwGetFramebufferSize(window_handle, &width, &height);

            return gfx.Swapchain{
                .width = width,
                .height = height,
                .sample_count = 4,
                .color_format = gfx.PixelFormat.RGBA8,
                .depth_format = gfx.PixelFormat.DEPTH_STENCIL,
            };
        }
    };
}.init);
