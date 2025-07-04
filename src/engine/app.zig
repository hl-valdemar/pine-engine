const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");

const log = @import("log.zig");
const Message = @import("message.zig").Message;
const Schedule = @import("schedule.zig").Schedule;

const WindowEvent = @import("pine-window").Event;

/// Config with sensible defaults for the app.
pub const AppDesc = struct {
    // ECS related
    remove_empty_archetypes: bool = true,
};

pub const App = struct {
    allocator: Allocator,
    config: AppDesc,
    registry: ecs.Registry,

    pub fn init(allocator: Allocator, config: AppDesc) !App {
        var app = App{
            .allocator = allocator,
            .config = config,
            .registry = try ecs.Registry.init(allocator, .{
                .remove_empty_archetypes = config.remove_empty_archetypes,
            }),
        };

        try app.registerResource(Message);

        return app;
    }

    pub fn deinit(self: *App) void {
        self.registry.deinit();
    }

    /// Run the app.
    pub fn run(self: *App) !void {
        const system_process_err_fmt = "failed to process systems with tag [{s}]: {}";

        // first initialize the app
        if (self.systemRegistered(.init)) {
            self.processSystems(.init) catch |err| {
                log.warn(system_process_err_fmt, .{ Schedule.init.toString(), err });
            };
        }
        if (self.systemRegistered(.post_init)) {
            self.processSystems(.post_init) catch |err| {
                log.warn(system_process_err_fmt, .{ Schedule.post_init.toString(), err });
            };
        }

        // run an update/render loop if any update systems are registered
        if (self.systemRegistered(.pre_update) or
            self.systemRegistered(.update) or
            self.systemRegistered(.post_update) or
            self.systemRegistered(.render))
        {
            var first = self.registry.queryResource(Message) catch unreachable; // Message should always be registered!
            defer first.deinit();

            const message_ptr = try self.allocator.create(?Message);
            defer self.allocator.destroy(message_ptr);
            message_ptr.* = first.next();

            while (message_ptr.* == null or message_ptr.*.? != Message.shutdown) {
                // note: system events may be generated here
                if (self.systemRegistered(.pre_update)) {
                    self.processSystems(.pre_update) catch |err| {
                        log.err(system_process_err_fmt, .{ Schedule.pre_update.toString(), err });
                    };
                }

                // note: user messages may be generated here
                if (self.systemRegistered(.update)) {
                    self.processSystems(.update) catch |err| {
                        log.err(system_process_err_fmt, .{ Schedule.update.toString(), err });
                    };
                }

                // note: internal systems get a chance to react to user messages here
                if (self.systemRegistered(.post_update)) {
                    self.processSystems(.post_update) catch |err| {
                        log.err(system_process_err_fmt, .{ Schedule.post_update.toString(), err });
                    };
                }

                // render the frame
                if (self.systemRegistered(.render)) {
                    self.processSystems(.render) catch |err| {
                        log.err(system_process_err_fmt, .{ Schedule.render.toString(), err });
                    };
                }

                // store this value before clearing!
                // question: maybe the shutdown message could be burried under other messages - iterate to search for it?
                var messages = self.registry.queryResource(Message) catch unreachable;
                defer messages.deinit();
                message_ptr.* = messages.next();

                // clear all events including those not acted upon
                if (self.resourceRegistered(WindowEvent)) {
                    self.registry.clearResource(WindowEvent) catch unreachable;
                }

                // clear messages from previous iteration including those not acted upon
                self.registry.clearResource(Message) catch unreachable;
            }
        }

        // when done, clean up
        if (self.systemRegistered(.deinit)) {
            self.processSystems(.deinit) catch |err| {
                log.err(system_process_err_fmt, .{ Schedule.deinit.toString(), err });
            };
        }
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
    pub fn spawn(self: *App, components: anytype) !ecs.EntityID {
        return try self.registry.spawn(components);
    }

    /// Register a system in the app.
    pub fn registerSystem(self: *App, comptime System: type, schedule: Schedule) !void {
        try self.registry.registerTaggedSystem(System, schedule.toString());
    }

    /// Register a resource in the app.
    pub fn registerResource(self: *App, comptime Resource: type) !void {
        try self.registry.registerResource(Resource);
    }

    /// Check whether a system was registered.
    ///
    /// FIXME: implement this in pine-ecs instead
    pub fn systemRegistered(self: *App, schedule: Schedule) bool {
        return self.registry.system_manager.tagged_systems.contains(schedule.toString());
    }

    // FIXME: implement this in pine-ecs instead
    pub fn resourceRegistered(self: *App, comptime Resource: type) bool {
        return self.registry.resources.contains(@typeName(Resource));
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
    pub fn addPlugin(self: *App, plugin: ecs.Plugin) !void {
        try self.registry.addPlugin(plugin);
    }

    fn processSystems(self: *App, schedule: Schedule) !void {
        try self.registry.processSystemsTagged(schedule.toString());
    }
};
