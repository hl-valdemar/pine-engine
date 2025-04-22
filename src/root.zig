const std = @import("std");
const Allocator = std.mem.Allocator;

const pecs = @import("pecs");
const sokol = @import("sokol");

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
            self.registry.updateSystemsTagged("init");
        }
    }

    export fn sokolFrame(app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));
            self.registry.updateSystemsTagged("update");

            self.registry.clearResource(EventType) catch |err| {
                std.debug.print("failed to clear event resource: {}\n", .{err});
            };
        }
    }

    export fn sokolEvent(ev: EventType, app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));

            self.registry.pushResource(ev) catch |err| {
                std.debug.print("failed to push event resource: {}\n", .{err});
            };
        }
    }

    export fn sokolCleanup(app_state: ?*anyopaque) void {
        if (app_state) |state| {
            const self: *AppState = @alignCast(@ptrCast(state));
            self.registry.updateSystemsTagged("deinit");
        }
    }
};

const SetupSystem = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) anyerror!SetupSystem {
        return SetupSystem{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SetupSystem) void {
        _ = self;
    }

    pub fn update(self: *SetupSystem, registry: *pecs.Registry) anyerror!void {
        _ = self;
        _ = registry;

        sokol.gfx.setup(.{
            .environment = sokol.glue.environment(),
            .logger = .{ .func = sokol.log.func },
        });
    }
};

const CleanupSystem = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) anyerror!CleanupSystem {
        return CleanupSystem{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CleanupSystem) void {
        _ = self;
    }

    pub fn update(self: *CleanupSystem, registry: *pecs.Registry) anyerror!void {
        _ = self;
        _ = registry;

        sokol.gfx.shutdown();
    }
};
