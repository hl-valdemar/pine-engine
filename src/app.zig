const std = @import("std");
const Allocator = std.mem.Allocator;

const pecs = @import("pecs");
const sokol = @import("sokol");

const pine = @import("root.zig");

pub const EventType = [*c]const sokol.app.Event;

pub const AppDesc = struct {
    const default_size = 200;

    // default 4/3 aspect ratio, as God intended it
    const default_aspect_width = 4;
    const default_aspect_height = 3;

    width: i32 = default_aspect_width * default_size,
    height: i32 = default_aspect_height * default_size,
    sample_count: i32 = 2,
    title: [*c]const u8 = "Pine Engine",
};

pub const Schedule = enum {
    Init,
    Deinit,
    Update,
};

pub const AppState = struct {
    allocator: Allocator,
    desc: AppDesc,
    registry: pecs.Registry,

    pub fn init(allocator: Allocator, desc: AppDesc) !AppState {
        var state = AppState{
            .allocator = allocator,
            .desc = desc,
            .registry = try pecs.Registry.init(allocator, .{ .remove_empty_archetypes = true }),
        };

        try state.registry.registerResource(EventType);

        try state.registry.registerTaggedSystem(SetupSystem, "init");
        try state.registry.registerTaggedSystem(CleanupSystem, "deinit");
        try state.registry.registerTaggedSystem(RenderSystem, "update");

        return state;
    }

    pub fn deinit(self: *AppState) void {
        self.registry.deinit();
    }

    pub fn run(self: *AppState) void {
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

    pub fn registerSystem(self: *AppState, comptime SystemType: type, schedule: Schedule) !void {
        const tag = switch (schedule) {
            Schedule.Init => "init",
            Schedule.Deinit => "deinit",
            Schedule.Update => "update",
        };
        try self.registry.registerTaggedSystem(SystemType, tag);
    }

    export fn sokolInit(app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));
            self.registry.processSystemsTagged("init") catch |err| {
                pine.log.err("failed to process systems with tag 'init': {}", .{err});
            };
        }
    }

    export fn sokolFrame(app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));

            self.registry.processSystemsTagged("update") catch |err| {
                pine.log.err("failed to process systems with tag 'update': {}", .{err});
            };

            // clear all events
            // note: events not acted upon will be lost
            self.registry.clearResource(EventType) catch |err| {
                pine.log.err("failed to clear event resource: {}", .{err});
            };
        }
    }

    export fn sokolEvent(ev: EventType, app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));

            // push the event to the relevant resource buffer
            self.registry.pushResource(ev) catch |err| {
                pine.log.err("failed to push event resource: {}", .{err});
            };
        }
    }

    export fn sokolCleanup(app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));
            self.registry.processSystemsTagged("deinit") catch |err| {
                pine.log.err("failed to process systems with tag 'deinit': {}", .{err});
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

const RenderSystem = struct {
    pub fn init(_: Allocator) anyerror!RenderSystem {
        return RenderSystem{};
    }

    pub fn deinit(_: *RenderSystem) void {}

    pub fn process(_: *RenderSystem, _: *pecs.Registry) anyerror!void {
        var pass = sokol.gfx.Pass{};
        pass.action.colors[0] = sokol.gfx.ColorAttachmentAction{
            .load_action = .CLEAR,
            // .store_action = .DONTCARE,
            .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
        };
        pass.swapchain = sokol.glue.swapchain();
        sokol.gfx.beginPass(pass);
        sokol.gfx.endPass();
        sokol.gfx.commit();
    }
};
