const std = @import("std");
const Allocator = std.mem.Allocator;

const ecs = @import("pine-ecs");

const log = @import("log.zig");
const Message = @import("message.zig").Message;

const WindowEvent = @import("pine-window").Event;

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
        var app = App{
            .allocator = allocator,
            .config = config,
            .registry = try ecs.Registry.init(allocator, .{
                .destroy_empty_archetypes = config.destroy_empty_archetypes,
            }),
        };

        // register critical resources
        try app.registerResource(Message);

        // set up the default pipeline stages
        try app.registry.pipeline.addStage("startup", .{});
        try app.registry.pipeline.addStage("update", .{});
        try app.registry.pipeline.addStage("render", .{});
        try app.registry.pipeline.addStage("cleanup", .{});

        // add default substages for update
        const update_stage = app.registry.pipeline.getStage("update").?;
        try update_stage.addSubstage("pre", .{});
        try update_stage.addSubstage("main", .{});
        try update_stage.addSubstage("post", .{});

        // add default substages for render
        const render_stage = app.registry.pipeline.getStage("render").?;
        try render_stage.addSubstage("pre", .{});
        try render_stage.addSubstage("main", .{});
        try render_stage.addSubstage("post", .{});

        return app;
    }

    pub fn deinit(self: *App) void {
        self.registry.deinit();
    }

    /// Run the app.
    pub fn run(self: *App) !void {
        // execute startup stage
        self.registry.pipeline.executeStages(&self.registry, &.{"startup"}) catch |err| {
            log.err("startup failed: {}", .{err});
        };

        // main loop
        if (self.registry.pipeline.hasStages(&.{ "update", "render" }, .@"or")) {
            var should_quit = false;

            while (!should_quit) {
                // execute update and render stages
                self.registry.pipeline.executeStages(&self.registry, &.{ "update", "render" }) catch |err| {
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
        self.registry.pipeline.executeStages(&self.registry, &.{"cleanup"}) catch |err| {
            log.err("cleanup failed: {}", .{err});
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
    pub fn spawn(self: *App, components: anytype) !ecs.EntityID {
        return try self.registry.spawn(components);
    }

    pub fn addSystem(self: *App, stage_path: []const u8, comptime System: type) !void {
        // parse stage path (e.g., "update.pre" -> stage: "update", substage: "pre")
        var it = std.mem.splitScalar(u8, stage_path, '.');
        const stage_name = it.next() orelse return error.InvalidStagePath;
        const substage_name = it.next();

        if (substage_name) |sub| {
            // register in substage
            if (self.registry.pipeline.getStage(stage_name)) |stage| {
                if (stage.substages) |*substages| {
                    try substages.addSystem(sub, System);
                } else return error.SubstageNotFound;
            } else return error.StageNotFound;
        } else {
            // register directly in stage
            try self.registry.pipeline.addSystem(stage_name, System);
        }
    }

    /// Register a resource in the app.
    pub fn registerResource(self: *App, comptime Resource: type) !void {
        try self.registry.registerResource(Resource);
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
};
