const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");
const pg = @import("pine-graphics");
const pw = @import("pine-window");

const Schedule = @import("schedule.zig").Schedule;
const WindowComponent = @import("window.zig").WindowComponent;

// global graphics context object
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
            .swapchain = try pg.Swapchain.create(&g_graphics_ctx, window),
        };
    }
};

/// A resource containing the frame count of the program.
pub const FrameCount = struct {
    value: u64,
};

/// A resource containing the frame time in seconds.
pub const FrameTime = struct {
    value: f64, // seconds
};

pub const RenderPlugin = ecs.Plugin.init("renderer", struct {
    fn init(registry: *ecs.Registry) anyerror!void {
        // initialize the global graphics context
        g_graphics_ctx = try pg.GraphicsContext.create(.auto);

        // register resources
        try registry.registerResource(FrameCount);
        try registry.registerResource(FrameTime);

        // push initial values
        try registry.pushResource(FrameCount{ .value = 0 });
        try registry.pushResource(FrameTime{ .value = 0 });

        try registry.registerTaggedSystem(RenderSystem, Schedule.render.toString());
        try registry.registerTaggedSystem(CleanupSystem, Schedule.render_deinit.toString());
    }

    const RenderSystem = struct {
        frame_count: u64,

        pub fn init(_: Allocator) anyerror!RenderSystem {
            return RenderSystem{
                .frame_count = 0,
            };
        }

        pub fn deinit(_: *RenderSystem) void {}

        pub fn process(self: *RenderSystem, registry: *ecs.Registry) anyerror!void {
            var frame_time_secs: f64 = 0;
            { // frame scope
                const start_time_nanos = std.time.nanoTimestamp();
                defer { // execute at end of frame scope
                    frame_time_secs = elapsedTimeSecs(start_time_nanos);
                    self.frame_count += 1;
                }

                var window_entities = try registry.queryComponents(.{RenderTargetComponent});
                while (window_entities.next()) |entity| {
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

                    // render commands would go here...

                    // end render pass and present the frame
                    render_pass.end();
                    swapchain.present();
                }
            }

            // push the frame count
            try registry.clearResource(FrameCount);
            try registry.pushResource(FrameCount{ .value = self.frame_count });

            // push the frame time
            try registry.clearResource(FrameTime);
            try registry.pushResource(FrameTime{ // nanoseconds -> seconds
                .value = frame_time_secs,
            });
        }

        fn elapsedTimeNanos(start_time_nanos: i128) i128 {
            return std.time.nanoTimestamp() - start_time_nanos;
        }

        fn elapsedTimeSecs(start_time_nanos: i128) f64 {
            return @as(f64, @floatFromInt(elapsedTimeNanos(start_time_nanos))) /
                1_000_000_000.0;
        }
    };

    const CleanupSystem = struct {
        pub fn init(_: Allocator) anyerror!CleanupSystem {
            return CleanupSystem{};
        }

        pub fn deinit(_: *CleanupSystem) void {}

        pub fn process(_: *CleanupSystem, registry: *ecs.Registry) anyerror!void {
            // destroy all swapchains
            var renderables = try registry.queryComponents(.{RenderTargetComponent});
            while (renderables.next()) |entity| {
                const target = entity.get(RenderTargetComponent).?;
                target.swapchain.destroy();
            }
            // destroy global graphics context
            g_graphics_ctx.destroy();
        }
    };
}.init);
