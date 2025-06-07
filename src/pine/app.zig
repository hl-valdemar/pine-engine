const std = @import("std");
const Allocator = std.mem.Allocator;

const pecs = @import("pecs");
const glfw = @import("glfw");

const log = @import("log.zig");

/// For communication outward.
pub const Event = enum {};

/// For communication inward.
pub const Message = enum {
    /// Special as this value is checked explicitly in the update loop.
    RequestQuit,
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

/// Config with sensible defaults for the app.
pub const AppConfig = struct {
    // ECS related
    remove_empty_archetypes: bool = true,
};

pub const App = struct {
    allocator: Allocator,
    config: AppConfig,
    registry: pecs.Registry,

    pub fn init(allocator: Allocator, config: AppConfig) !App {
        var app = App{
            .allocator = allocator,
            .config = config,
            .registry = try pecs.Registry.init(allocator, .{
                .remove_empty_archetypes = config.remove_empty_archetypes,
            }),
        };

        try app.registerResource(Event);
        try app.registerResource(Message);

        // try app.addPlugin(SetupPlugin);

        try app.registerSystem(MessageHandlerSystem, .PostUpdate);

        return app;
    }

    pub fn deinit(self: *App) void {
        self.registry.deinit();
    }

    /// Run the app.
    pub fn run(self:*App) void {
        const system_process_err_fmt = "failed to process systems with tag '{s}': {}";

        // first initialize the app
        self.processSystems(.Init) catch |err| {
            log.warn(system_process_err_fmt, .{ Schedule.Init.toString(), err });
        };

        // run an update loop if any update systems are registered
        if (self.registry.system_manager.tagged_systems.get(Schedule.Update.toString())) |_| {
            const resource_clear_err_fmt = "failed to clear '{s}' resource: {}";

            var result = self.registry.queryResource(Message) catch unreachable; // Message should always be registered!
            var message = result.next();

            while (message == null or message.?.* != Message.RequestQuit) {
                // note: system messages may be added here
                self.processSystems(.Update) catch |err| {
                    log.err(system_process_err_fmt, .{ Schedule.Update.toString(), err });
                };

                self.processSystems(.PostUpdate) catch |err| {
                    log.err(system_process_err_fmt, .{ Schedule.PostUpdate.toString(), err });
                };

                // store this value before clearing!
                result = self.registry.queryResource(Message) catch unreachable; // Message should always be registered!
                message = result.next();

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

        // when done, clean up
        self.processSystems(.Deinit) catch |err| {
            log.err(system_process_err_fmt, .{Schedule.Deinit.toString(), err});
        };
    }

    /// Spawn an entity with initial components.
    ///
    /// An example might look as follows:
    /// ```zig
    /// const entity = try app.spawn(.{
    ///     Player{},
    ///     Health{ .current = 3, .max = 5 },
    /// });
    /// ```
    pub fn spawn(self: *App, components: anytype) !pecs.EntityID {
        return try self.registry.spawn(components);
    }

    /// Register a system in the app.
    pub fn registerSystem(self: *App, comptime SystemType: type, schedule: Schedule) !void {
        try self.registry.registerTaggedSystem(SystemType, schedule.toString());
    }

    /// Register a resource in the app.
    pub fn registerResource(self: *App, comptime ResourceType: type) !void {
        try self.registry.registerResource(ResourceType);
    }

    /// Add a plugin bundling behavior.
    ///
    /// Plugins can be used to bundle behavior and might look as follows:
    ///
    /// ```zig
    /// pub const HealthPlugin = Plugin.init("Health", struct {
    ///     const Health = struct { current: f32, max: f32 };
    ///     const Damage = struct { amount: f32 };
    ///
    ///     fn init(registry: *Registry) !void {
    ///         try registry.registerTaggedSystem(HealthSystem, "health");
    ///         try registry.registerTaggedSystem(DamageSystem, "health");
    ///     }
    ///
    ///     // ... system implementations ...
    /// }.init);
    ///
    /// app.addPlugin(HealthPlugin);
    /// ```
    pub fn addPlugin(self: *App, plugin: pecs.Plugin) !void {
        try self.registry.addPlugin(plugin);
    }

    fn processSystems(self: *App, schedule: Schedule) !void {
        try self.registry.processSystemsTagged(schedule.toString());
    }
};

// pub const SetupPlugin = pecs.Plugin.init("wetup", struct {
//     // declare components here...
//
//     fn init(registry: *pecs.Registry) !void {
//         try registry.registerTaggedSystem(SetupCore, Schedule.Init.toString());
//     }
//
//     const SetupCore = struct {
//         pub fn init(_: std.mem.Allocator) anyerror!SetupCore {
//             return SetupCore{};
//         }
//
//         pub fn deinit(_: *SetupCore) void {}
//
//         pub fn process(_: *SetupCore, registry: *pecs.Registry) anyerror!void {
//             _ = registry;
//         }
//     };
// }.init);

pub const WindowPlugin = pecs.Plugin.init("window", struct {
    var window: *glfw.Window = undefined;

    fn init(registry: *pecs.Registry) !void {
        try registry.registerTaggedSystem(SetupGLFW, Schedule.Init.toString());
        try registry.registerTaggedSystem(CleanupGLFW, Schedule.Deinit.toString());
        try registry.registerTaggedSystem(CreateWindow, Schedule.Init.toString());
        try registry.registerTaggedSystem(PollEvents, Schedule.Update.toString());
    }

    const SetupGLFW = struct {
        pub fn init(_: std.mem.Allocator) anyerror!SetupGLFW {
            return SetupGLFW{};
        }

        pub fn deinit(_: *SetupGLFW) void {}

        pub fn process(_: *SetupGLFW, registry: *pecs.Registry) anyerror!void {
            _ = registry;

            var major: i32 = 0;
            var minor: i32 = 0;
            var rev: i32 = 0;

            glfw.getVersion(&major, &minor, &rev);
            log.info("using GLFW v{}.{}.{}", .{ major, minor, rev });

            try glfw.init();
        }
    };

    const CleanupGLFW = struct {
        pub fn init(_: std.mem.Allocator) anyerror!CleanupGLFW {
            return CleanupGLFW{};
        }

        pub fn deinit(_: *CleanupGLFW) void {}

        pub fn process(_: *CleanupGLFW, registry: *pecs.Registry) anyerror!void {
            _ = registry;
            log.info("destroying window...", .{});
            glfw.destroyWindow(window);

            log.info("terminating GLFW...", .{});
            glfw.terminate();
        }
    };

    const CreateWindow = struct {
        pub fn init(_: std.mem.Allocator) anyerror!CreateWindow {
            return CreateWindow{};
        }

        pub fn deinit(_: *CreateWindow) void {}

        pub fn process(_: *CreateWindow, registry: *pecs.Registry) anyerror!void {
            _ = registry;
            log.info("creating window...", .{});
            window = try glfw.createWindow(500, 500, "Pine Test", null, null);
        }
    };

    const PollEvents = struct {
        pub fn init(_: std.mem.Allocator) anyerror!PollEvents {
            return PollEvents{};
        }

        pub fn deinit(_: *PollEvents) void {}

        pub fn process(_: *PollEvents, registry: *pecs.Registry) anyerror!void {
            glfw.pollEvents();

            if (glfw.windowShouldClose(window)) {
                try registry.pushResource(Message.RequestQuit);
            }
        }
    };
}.init);

const MessageHandlerSystem = struct {
    pub fn init(_: Allocator) anyerror!MessageHandlerSystem {
        return MessageHandlerSystem{};
    }

    pub fn deinit(_: *MessageHandlerSystem) void {}

    pub fn process(_: *MessageHandlerSystem, registry: *pecs.Registry) anyerror!void {
        var result = try registry.queryResource(Message);
        while (result.next()) |message| {
            if (message.* == .RequestQuit) {
                // ...
            }
        }
    }
};
