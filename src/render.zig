const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pg = @import("pine-graphics");
const pw = @import("pine-window");

const log = @import("log.zig");
const elapsedTimeSecs = @import("time.zig").elapsedTimeSecs;
const WindowComponent = @import("window.zig").WindowComponent;

// global graphics context object
// FIXME: should probably be converted to an optional
var g_graphics_ctx: pg.GraphicsContext = undefined;

pub const Color = struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,
};

pub const RenderTargetDesc = struct {
    clear_color: Color,
};

pub const RenderTargetComponent = struct {
    clear_color: Color,
    swapchain: pg.Swapchain,

    pub fn init(window: *pw.Window, desc: RenderTargetDesc) !RenderTargetComponent {
        return RenderTargetComponent{
            .clear_color = desc.clear_color,
            .swapchain = try pg.Swapchain.init(&g_graphics_ctx, window),
        };
    }
};

/// A resource containing the frame count of the program.
pub const FrameCount = struct {
    value: u64,
    window_id: pw.WindowID,
};

/// A resource containing the frame time in seconds.
pub const FrameTime = struct {
    value: f64, // seconds
    window_id: pw.WindowID,
};

pub const RenderPlugin = ecs.Plugin.init("render", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        // initialize the global graphics context
        g_graphics_ctx = try pg.GraphicsContext.init(.auto);

        // register resources
        try registry.registerResource(FrameCount, .collection);
        try registry.registerResource(FrameTime, .collection);

        // add render systems to appropriate substages
        try registry.addSystem("render.main", RenderSystem);
        try registry.addSystem("cleanup", CleanupSystem);
    }

    const RenderSystem = struct {
        frame_count: u64,

        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{
                .frame_count = 0,
            };
        }

        pub fn process(self: *RenderSystem, registry: *ecs.Registry) anyerror!void {
            // ready frame info for next pass
            try registry.clearResource(FrameCount);
            try registry.clearResource(FrameTime);

            var frame_time_secs: f64 = 0;
            { // frame scope
                const start_time_nanos = std.time.nanoTimestamp();
                defer { // execute at end of frame scope
                    frame_time_secs = elapsedTimeSecs(start_time_nanos);
                    self.frame_count += 1;
                }

                var window_query = try registry.queryComponents(.{ WindowComponent, RenderTargetComponent });
                defer window_query.deinit();

                while (window_query.next()) |entity| {
                    const target = entity.get(RenderTargetComponent).?;
                    var swapchain = target.swapchain;

                    // begin render pass
                    var render_pass = try pg.beginPass(&swapchain, .{
                        .color = .{
                            .action = .clear,
                            .r = target.clear_color.r,
                            .g = target.clear_color.g,
                            .b = target.clear_color.b,
                            .a = target.clear_color.a,
                        },
                    });

                    // render commands go here...

                    // end render pass and present the frame
                    render_pass.end();
                    swapchain.present();

                    // push frame info
                    const window = entity.get(WindowComponent).?;
                    try registry.pushResource(FrameCount{
                        .value = self.frame_count,
                        .window_id = window.handle.id,
                    });
                    try registry.pushResource(FrameTime{
                        .value = frame_time_secs,
                        .window_id = window.handle.id,
                    });
                }
            }
        }
    };

    const CleanupSystem = struct {
        // FIXME: is cleanup in window plugin sufficiently cleaning up render objects?
        pub fn process(_: *CleanupSystem, _: *ecs.Registry) anyerror!void {
            // // destroy all swapchains
            // var renderables = try registry.queryComponents(.{RenderTargetComponent});
            // defer renderables.deinit();
            //
            // while (renderables.next()) |entity| {
            //     const target = entity.get(RenderTargetComponent).?;
            //     target.swapchain.destroy();
            // }

            // destroy global graphics context
            g_graphics_ctx.deinit();
        }
    };
}.init);
