const std = @import("std");
const Allocator = std.mem.Allocator;

const pecs = @import("pecs");
const sokol = @import("sokol");

const log = @import("log.zig");

/// For communication outward.
pub const Event = sokol.app.Event;

/// For communication inward.
pub const Message = enum {
    RequestQuit,
};

/// Config with sensible defaults for the app.
pub const AppConfig = struct {
    const default_size = 200;

    // default 4/3 aspect ratio, as God intended it
    const default_aspect_width = 4;
    const default_aspect_height = 3;

    width: i32 = default_aspect_width * default_size,
    height: i32 = default_aspect_height * default_size,
    sample_count: i32 = 2,
    title: [*c]const u8 = "Pine Engine",
};

/// Schedule systems.
pub const Schedule = enum {
    /// Run once on app initialization.
    Init,

    /// Run once on app deinitialization.
    Deinit,

    /// Run every frame (before PostUpdate).
    Update,

    /// Run every frame (after Update).
    PostUpdate,

    /// Run every frame (after Update and PostUpdate).
    Render,

    /// Return a string representation of the schedule value.
    pub fn toString(self: Schedule) []const u8 {
        return @tagName(self);
    }
};

pub const App = struct {
    allocator: Allocator,
    desc: AppConfig,
    registry: pecs.Registry,

    pub fn init(allocator: Allocator, desc: AppConfig) !App {
        var app = App{
            .allocator = allocator,
            .desc = desc,
            .registry = try pecs.Registry.init(allocator, .{ .remove_empty_archetypes = true }),
        };

        try app.registerResource(Event);
        try app.registerResource(Message);

        try app.registerSystem(SetupSystem, .Init);
        try app.registerSystem(CleanupSystem, .Deinit);
        try app.registerSystem(MessageHandlerSystem, .PostUpdate);
        try app.registerSystem(RenderSystem, .Render);

        return app;
    }

    pub fn deinit(self: *App) void {
        self.registry.deinit();
    }

    /// Run the app.
    pub fn run(self: *App) void {
        sokol.app.run(.{
            .init_userdata_cb = sokolInit,
            .frame_userdata_cb = sokolFrame,
            .event_userdata_cb = sokolEvent,
            .cleanup_userdata_cb = sokolCleanup,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = self.desc.sample_count,
            .width = self.desc.width,
            .height = self.desc.height,
            .window_title = self.desc.title,
        });
    }

    /// Register a system in the app.
    pub fn registerSystem(self: *App, comptime SystemType: type, schedule: Schedule) !void {
        try self.registry.registerTaggedSystem(SystemType, schedule.toString());
    }

    /// Register a resource in the app.
    pub fn registerResource(self: *App, comptime ResourceType: type) !void {
        try self.registry.registerResource(ResourceType);
    }

    fn processSystems(self: *App, schedule: Schedule) !void {
        try self.registry.processSystemsTagged(schedule.toString());
    }

    export fn sokolInit(app: ?*anyopaque) void {
        if (app) |a| {
            const self: *App = @alignCast(@ptrCast(a));
            self.processSystems(.Init) catch |err| {
                log.err("failed to process systems with tag '{s}': {}", .{ Schedule.Init.toString(), err });
            };
        }
    }

    export fn sokolFrame(app: ?*anyopaque) void {
        if (app) |a| {
            const self: *App = @alignCast(@ptrCast(a));

            const system_process_err_fmt = "failed to process systems with tag '{s}': {}";
            const resource_clear_err_fmt = "failed to clear '{s}' resource: {}";

            // note: system messages may be added here
            self.processSystems(.Update) catch |err| {
                log.err(system_process_err_fmt, .{ Schedule.Update.toString(), err });
            };

            self.processSystems(.PostUpdate) catch |err| {
                log.err(system_process_err_fmt, .{ Schedule.PostUpdate.toString(), err });
            };

            self.processSystems(.Render) catch |err| {
                log.err(system_process_err_fmt, .{ Schedule.Render.toString(), err });
            };

            // clear all events including those not acted upon
            self.registry.clearResource(Event) catch |err| {
                log.err(resource_clear_err_fmt, .{ @typeName(Event), err });
            };

            // clear messages from previous iteration including those not acted upon
            self.registry.clearResource(Message) catch |err| {
                log.err(resource_clear_err_fmt, .{ @typeName(Message), err });
            };
        }
    }

    export fn sokolEvent(event: [*c]const Event, app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *App = @alignCast(@ptrCast(state));

            // push the event to the relevant resource buffer
            self.registry.pushResource(event.*) catch |err| {
                log.err("failed to push event resource: {}", .{err});
            };
        }
    }

    export fn sokolCleanup(app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *App = @alignCast(@ptrCast(state));

            // process cleanup systems
            self.processSystems(.Deinit) catch |err| {
                log.err("failed to process systems with tag '{s}': {}", .{ Schedule.Deinit.toString(), err });
            };
        }
    }
};

const SetupSystem = struct {
    pub fn init(_: Allocator) anyerror!SetupSystem {
        return SetupSystem{};
    }

    pub fn deinit(_: *SetupSystem) void {}

    pub fn process(_: *SetupSystem, _: *pecs.Registry) anyerror!void {
        sokol.gfx.setup(.{
            .environment = sokol.glue.environment(),
            .logger = .{ .func = sokol.log.func },
        });
    }
};

const CleanupSystem = struct {
    pub fn init(_: Allocator) anyerror!CleanupSystem {
        return CleanupSystem{};
    }

    pub fn deinit(_: *CleanupSystem) void {}

    pub fn process(_: *CleanupSystem, _: *pecs.Registry) anyerror!void {
        sokol.gfx.shutdown();
    }
};

const MessageHandlerSystem = struct {
    pub fn init(_: Allocator) anyerror!MessageHandlerSystem {
        return MessageHandlerSystem{};
    }

    pub fn deinit(_: *MessageHandlerSystem) void {}

    pub fn process(_: *MessageHandlerSystem, registry: *pecs.Registry) anyerror!void {
        var result = try registry.queryResource(Message);
        while (result.next()) |message| {
            if (message.* == .RequestQuit) {
                sokol.app.requestQuit();
            }
        }
    }
};

const RenderSystem = struct {
    pub fn init(_: Allocator) anyerror!RenderSystem {
        return RenderSystem{};
    }

    pub fn deinit(_: *RenderSystem) void {}

    pub fn process(_: *RenderSystem, _: *pecs.Registry) anyerror!void {
        var pass = sokol.gfx.Pass{};

        const rad: f32 = @floatFromInt(sokol.app.frameCount());
        const amp = 0.95;
        const freq = 0.0125;
        const offset = 2.0 * std.math.pi / 3.0;

        const r: f32 = amp * @sin(freq * rad + 0.0 * offset);
        const g: f32 = amp * @sin(freq * rad + 0.0 * offset);
        const b: f32 = amp * @sin(freq * rad + 0.0 * offset);

        pass.action.colors[0] = sokol.gfx.ColorAttachmentAction{
            .load_action = .CLEAR,
            .clear_value = .{ .r = r, .g = g, .b = b, .a = 1 },
        };
        pass.swapchain = sokol.glue.swapchain();

        sokol.gfx.beginPass(pass);
        sokol.gfx.endPass();

        sokol.gfx.commit();
    }
};
