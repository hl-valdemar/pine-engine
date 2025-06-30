// const std = @import("std");
// const Allocator = std.mem.Allocator;
//
// const pecs = @import("pecs");
// const sokol = @import("sokol");
// const gfx = sokol.gfx;
//
// const Schedule = @import("schedule.zig").Schedule;
// const WindowComponent = @import("window.zig").WindowComponent;
//
// const c = @cImport({
//     @cInclude("GLFW/glfw3.h");
//     // For macOS Metal support
//     @cDefine("GLFW_INCLUDE_NONE", {});
//     @cDefine("GLFW_EXPOSE_NATIVE_COCOA", {});
//     @cInclude("GLFW/glfw3native.h");
// });
//
// pub const RenderPlugin = pecs.Plugin.init("renderer", struct {
//     fn init(registry: *pecs.Registry) anyerror!void {
//         try registry.registerTaggedSystem(RendererInitSystem, Schedule.Init.toString());
//         try registry.registerTaggedSystem(RenderSystem, Schedule.Render.toString());
//     }
//
//     const RendererInitSystem = struct {
//         pub fn init(_: Allocator) anyerror!RendererInitSystem {
//             return RendererInitSystem{};
//         }
//
//         pub fn deinit(_: *RendererInitSystem) void {
//             gfx.shutdown();
//         }
//
//         pub fn process(_: *RendererInitSystem, _: *pecs.Registry) anyerror!void {
//             sokol.gfx.setup(sokol.gfx.Desc{
//                 .environment = glfwEnvironment(),
//             });
//         }
//
//         fn glfwEnvironment() gfx.Environment {
//             return gfx.Environment{
//                 .defaults = .{
//                     .color_format = gfx.PixelFormat.RGBA8,
//                     .depth_format = gfx.PixelFormat.DEPTH_STENCIL,
//                     .sample_count = 4,
//                 },
//                 // metal-specific setup for macos
//                 .metal = .{
//                     .device = glfwMetalDevice(),
//                 },
//             };
//         }
//
//         fn glfwMetalDevice() ?*anyopaque {
//             // on macOS, glfw creates a Metal device automatically
//             // we can retrieve it if needed, but sokol can also create its own
//             return null; // Let Sokol create its own device
//         }
//     };
//
//     const RenderSystem = struct {
//         pub fn init(_: Allocator) anyerror!RenderSystem {
//             return RenderSystem{};
//         }
//
//         pub fn deinit(_: *RenderSystem) void {}
//
//         pub fn process(_: *RenderSystem, registry: *pecs.Registry) anyerror!void {
//             var window_entities = try registry.queryComponents(.{WindowComponent});
//             while (window_entities.next()) |entity| {
//                 const window = entity.get(WindowComponent).?;
//
//                 c.glfwMakeContextCurrent(window.handle);
//
//                 var width: c_int = undefined;
//                 var height: c_int = undefined;
//                 c.glfwGetFramebufferSize(window.handle, &width, &height);
//
//                 const swapchain = gfx.Swapchain{
//                     .width = @intCast(width),
//                     .height = @intCast(height),
//                     .sample_count = 4,
//                     .color_format = .RGBA8,
//                     .depth_format = .DEPTH_STENCIL,
//                     .gl = .{
//                         .framebuffer = 0, // Default framebuffer
//                     },
//                 };
//
//                 // Clear to a nice color
//                 var pass_action = gfx.PassAction{};
//                 pass_action.colors[0] = .{
//                     .load_action = .CLEAR,
//                     .clear_value = .{ .r = 0.1, .g = 0.2, .b = 0.3, .a = 1.0 },
//                 };
//
//                 gfx.beginPass(.{
//                     .action = pass_action,
//                     .swapchain = swapchain,
//                 });
//
//                 // Your rendering code here
//
//                 gfx.endPass();
//                 gfx.commit();
//
//                 c.glfwSwapBuffers(window.handle);
//             }
//         }
//     };
// }.init);

// src/pine/renderer.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

const pecs = @import("pecs");
const sokol = @import("sokol");
const gfx = sokol.gfx;

const glfw = @import("wrapper/glfw.zig");
const c = glfw.c;
const Schedule = @import("schedule.zig").Schedule;
const WindowComponent = @import("window.zig").WindowComponent;

pub const RenderPlugin = pecs.Plugin.init("renderer", struct {
    fn init(registry: *pecs.Registry) anyerror!void {
        try registry.registerTaggedSystem(RendererInitSystem, Schedule.PostInit.toString());
        try registry.registerTaggedSystem(RenderSystem, Schedule.Render.toString());
    }

    const RendererInitSystem = struct {
        pub fn init(_: Allocator) anyerror!RendererInitSystem {
            return RendererInitSystem{};
        }

        pub fn deinit(_: *RendererInitSystem) void {
            gfx.shutdown();
            std.log.info("renderer shut down", .{});
        }

        pub fn process(_: *RendererInitSystem, registry: *pecs.Registry) anyerror!void {
            // get the first window to create an opengl context
            var window_entities = try registry.queryComponents(.{WindowComponent});
            defer window_entities.deinit();

            if (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;

                // make this window's context current for sokol initialization
                c.glfwMakeContextCurrent(window.handle);

                // initialize sokol graphics with opengl backend
                gfx.setup(.{
                    .environment = .{
                        .defaults = .{
                            .color_format = .RGBA8,
                            .depth_format = .DEPTH_STENCIL,
                            .sample_count = 1,
                        },
                    },
                    .logger = .{ .func = sokol.log.func },
                });

                std.log.info("renderer initialized with OpenGL backend", .{});
            } else {
                return error.NoWindowsAvailable;
            }
        }
    };

    const RenderSystem = struct {
        clear_color: gfx.Color = .{
            .r = 0.1,
            .g = 0.2,
            .b = 0.3,
            .a = 1.0,
        },

        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{};
        }

        pub fn deinit(_: *RenderSystem) void {}

        pub fn process(self: *RenderSystem, registry: *pecs.Registry) anyerror!void {
            var window_entities = try registry.queryComponents(.{WindowComponent});

            // animate the clear color for visual feedback
            const time: f32 = @floatCast(@as(f64, @floatFromInt(std.time.milliTimestamp())) / 1000.0);
            self.clear_color.r = @abs(@sin(time * 0.5)) * 0.3;
            self.clear_color.g = @abs(@sin(time * 0.3)) * 0.3;
            self.clear_color.b = @abs(@sin(time * 0.7)) * 0.3 + 0.2;

            while (window_entities.next()) |entity| {
                const window = entity.get(WindowComponent).?;

                // skip windows that are minimized
                if (c.glfwGetWindowAttrib(window.handle, c.GLFW_ICONIFIED) == c.GLFW_TRUE)
                    continue;

                // make this window's gl context current
                c.glfwMakeContextCurrent(window.handle);

                // get framebuffer size (handles retina displays correctly)
                var fb_width: c_int = undefined;
                var fb_height: c_int = undefined;
                c.glfwGetFramebufferSize(window.handle, &fb_width, &fb_height);

                // skip if window has no size
                if (fb_width == 0 or fb_height == 0)
                    continue;

                // set viewport
                gfx.applyViewport(0, 0, fb_width, fb_height, true);

                // construct swapchain
                const swapchain = gfx.Swapchain{
                    .width = @intCast(fb_width),
                    .height = @intCast(fb_height),
                    .sample_count = 1,
                    .color_format = .RGBA8,
                    .depth_format = .DEPTH_STENCIL,
                    .gl = .{
                        .framebuffer = 0, // default framebuffer
                    },
                };

                // begin default render pass
                gfx.beginPass(.{
                    .action = .{
                        .colors = .{
                            .{
                                .load_action = .CLEAR,
                                .clear_value = self.clear_color,
                            },
                            .{}, .{}, .{}, // unused attachments
                        },
                        .depth = .{
                            .load_action = .CLEAR,
                            .clear_value = 1.0,
                        },
                        .stencil = .{
                            .load_action = .CLEAR,
                            .clear_value = 0,
                        },
                    },
                    .swapchain = swapchain,
                });

                // rendering commands would go here
                // for example: draw meshes, sprites, etc.

                gfx.endPass();
                gfx.commit();

                // swap buffers for this window
                c.glfwSwapBuffers(window.handle);
            }
        }
    };
}.init);
