const std = @import("std");
const Allocator = std.mem.Allocator;

const pecs = @import("pine-ecs");
const pterm = @import("pine-terminal");

pub const TermPositionComponent = struct {
    x: u16,
    y: u16,
};

pub const TermSpriteComponent = struct {
    symbol: u21,
    color: pterm.TermColor,
};

pub const RenderTerminalPlugin = pecs.Plugin.init("render-terminal", struct {
    fn init(registry: *pecs.Registry) anyerror!void {
        // register resources
        try registry.registerResource(pterm.Terminal, .single);
        try registry.registerResource(pterm.Screen, .single);
        try registry.registerResource(pterm.KeyEvent, .collection);

        // register systems
        try registry.addSystem("startup", InitSystem);
        try registry.addSystem("update.pre", EventPollingSystem);
        try registry.addSystem("flush", EventClearingSystem);
        try registry.addSystem("render.pre", PreRenderSystem);
        try registry.addSystem("render.main", RenderSystem);
        try registry.addSystem("render.post", PostRenderSystem);
        try registry.addSystem("cleanup", CleanupSystem);
    }

    const InitSystem = struct {
        allocator: Allocator,

        pub fn init(allocator: Allocator) anyerror!InitSystem {
            return InitSystem{ .allocator = allocator };
        }

        // responsible for pushing terminal critical resources to the registry
        pub fn process(self: *InitSystem, registry: *pecs.Registry) anyerror!void {
            // push resources
            var term = try pterm.Terminal.init(.{
                .alternate_screen = true,
                .hide_cursor = true,
                .enable_mouse = false,
            });
            const screen = try pterm.Screen.init(self.allocator, &term);

            try registry.pushResource(term);
            try registry.pushResource(screen);
        }
    };

    const PreRenderSystem = struct {
        pub fn process(_: *PreRenderSystem, registry: *pecs.Registry) anyerror!void {
            var screen = switch (try registry.queryResource(pterm.Screen)) {
                .single => |screen| screen.resource orelse return error.ScreenResourceNull,
                .collection => return error.InvalidResource,
            };

            screen.clear();
        }
    };

    const RenderSystem = struct {
        pub fn process(_: *RenderSystem, registry: *pecs.Registry) anyerror!void {
            var screen = switch (try registry.queryResource(pterm.Screen)) {
                .single => |screen| screen.resource orelse return error.ScreenResourceNull,
                .collection => return error.InvalidResource,
            };

            var renderable_query = try registry.queryComponents(.{ TermPositionComponent, TermSpriteComponent });
            defer renderable_query.deinit();

            while (renderable_query.next()) |renderable| {
                const position = renderable.get(TermPositionComponent).?;
                const sprite = renderable.get(TermSpriteComponent).?;

                screen.setCell(position.x, position.y, sprite.symbol, sprite.color);
            }
        }
    };

    const PostRenderSystem = struct {
        pub fn process(_: *PostRenderSystem, registry: *pecs.Registry) anyerror!void {
            var screen = switch (try registry.queryResource(pterm.Screen)) {
                .single => |screen| screen.resource orelse return error.ScreenResourceNull,
                .collection => return error.InvalidResource,
            };

            try screen.render();

            // small delay to avoid screen flicker
            std.time.sleep(5_000_000); // 5ms
        }
    };

    const EventPollingSystem = struct {
        pub fn process(_: *EventPollingSystem, registry: *pecs.Registry) anyerror!void {
            var term = switch (try registry.queryResource(pterm.Terminal)) {
                .single => |term| term.resource orelse return error.TermResourceNull,
                .collection => return error.InvalidResource,
            };

            // push events to the registry
            if (try term.pollEvent()) |event| {
                switch (event) {
                    .key => |key| try registry.pushResource(key),
                    else => {},
                }
            }
        }
    };

    const EventClearingSystem = struct {
        pub fn process(_: *EventClearingSystem, registry: *pecs.Registry) anyerror!void {
            try registry.clearResource(pterm.KeyEvent);
        }
    };

    const CleanupSystem = struct {
        pub fn process(_: *CleanupSystem, registry: *pecs.Registry) anyerror!void {
            try registry.clearResource(pterm.Terminal);
            try registry.clearResource(pterm.Screen);
        }
    };
}.init);
