const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");

const log = @import("log.zig");
const Message = @import("message.zig").Message;

const WindowEvent = @import("pine-window").Event;

// FIXME: replace any direct uses of WindowEvent with this Event type that wraps other event types
const Event = union(enum) {
    window_event: WindowEvent,
};

/// Config with sensible defaults for the app.
pub const AppDesc = struct {
    // ecs related
    destroy_empty_archetypes: bool = true,
};

pub const App = struct {
    allocator: Allocator,
    config: AppDesc,
    registry: ecs.Registry,

    pub fn init(allocator: Allocator, config: AppDesc) !App {
        log.info("booting kernel...", .{});

        var app = App{
            .allocator = allocator,
            .config = config,
            .registry = try ecs.Registry.init(allocator, .{
                .destroy_empty_archetypes = config.destroy_empty_archetypes,
            }),
        };

        // configure app-critical resources
        try app.registerDefaultResources();
        try app.setupDefaultPipeline();

        return app;
    }

    pub fn deinit(self: *App) void {
        self.registry.deinit();
    }

    /// Register the default resources.
    fn registerDefaultResources(self: *App) !void {
        try self.registerResource(Event);
        try self.registerResource(Message);
    }

    /// Setup the default pipeline.
    fn setupDefaultPipeline(self: *App) !void {
        // set up the default pipeline stages
        try self.addStage("startup", .{});
        try self.addStage("update", .{});
        try self.addStage("render", .{});
        try self.addStage("cleanup", .{});

        // add default substages for update
        const update_stage = self.getStage("update").?;
        try update_stage.addSubstage("pre", .{});
        try update_stage.addSubstage("main", .{});
        try update_stage.addSubstage("post", .{});

        // add default substages for render
        const render_stage = self.getStage("render").?;
        try render_stage.addSubstage("pre", .{});
        try render_stage.addSubstage("main", .{});
        try render_stage.addSubstage("post", .{});
    }

    /// Run the app.
    pub fn run(self: *App) !void {
        // execute startup stage
        log.info("booting userspace...", .{});
        self.executeStages(&.{"startup"}) catch |err| {
            log.err("startup failed: {}", .{err});
        };

        // main loop
        if (!self.stagesEmpty(&.{ "update", "render" }, .@"and")) {
            var should_quit = false;

            while (!should_quit) {
                // execute update and render stages
                self.executeStages(&.{ "update", "render" }) catch |err| {
                    log.err("update/render failed: {}", .{err});
                };

                // check for shutdown message
                var messages = try self.registry.queryResource(Message);
                defer messages.deinit();

                while (messages.next()) |message| {
                    if (message == .shutdown) {
                        should_quit = true;
                        break;
                    }
                }

                // clear all events and messages
                if (self.resourceRegistered(WindowEvent)) {
                    self.registry.clearResource(WindowEvent) catch unreachable;
                }
                self.registry.clearResource(Message) catch unreachable;
            }
        }

        // execute cleanup stage
        self.executeStages(&.{"cleanup"}) catch |err| {
            log.err("cleanup failed: {}", .{err});
        };

        log.info("shutting down...", .{});
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

    /// Register a resource in the app.
    pub fn registerResource(self: *App, comptime Resource: type) !void {
        try self.registry.registerResource(Resource);
    }

    // FIXME: implement this in pine-ecs instead
    pub fn resourceRegistered(self: *App, comptime Resource: type) bool {
        return self.registry.resourceRegistered(Resource);
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

    pub fn addStage(self: *App, name: []const u8, config: ecs.StageConfig) !void {
        try self.registry.addStage(name, config);
    }

    pub fn getStage(self: *App, name: []const u8) ?*ecs.Stage {
        return self.registry.getStage(name);
    }

    pub fn getStageNames(self: *App, allocator: Allocator) void {
        return try self.registry.getStageNames(allocator);
    }

    pub fn hasStages(
        self: *App,
        stage_names: []const []const u8,
        operation: ecs.Pipeline.BooleanOperation,
    ) bool {
        return self.registry.hasStages(stage_names, operation);
    }

    pub fn executeStages(
        self: *App,
        stage_names: []const []const u8,
    ) !void {
        try self.registry.executeStages(stage_names);
    }

    pub fn addSystem(
        self: *App,
        stage_path: []const u8,
        comptime System: type,
    ) !void {
        try self.registry.addSystem(stage_path, System);
    }

    pub fn addSystems(
        self: *App,
        stage_path: []const u8,
        comptime systems: anytype,
    ) !void {
        try self.registry.addSystems(stage_path, systems);
    }

    pub fn getSystemNames(
        self: *App,
        allocator: Allocator,
        stage_name: []const u8,
    ) ![][]const u8 {
        return try self.registry.getSystemNames(allocator, stage_name);
    }

    pub fn stageEmpty(self: *App, stage_name: []const u8) bool {
        return self.registry.stageEmpty(stage_name);
    }

    pub fn stagesEmpty(
        self: *App,
        stage_names: []const []const u8,
        operation: ecs.Pipeline.BooleanOperation,
    ) bool {
        return self.registry.stagesEmpty(stage_names, operation);
    }
};
