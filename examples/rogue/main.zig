const std = @import("std");
const Allocator = std.mem.Allocator;

const pine = @import("pine-engine");

const system = @import("system.zig");

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var app = try pine.App.init(allocator, .{});
    defer app.deinit();

    // add plugins
    try app.addPlugin(pine.RenderTerminalPlugin);

    // add systems
    try app.addSystem("startup", system.Setup);
    try app.addSystem("update.main", system.PlayerMove);
    try app.addSystem("update.main", system.Shutdown);
    try app.addSystem("update.main", system.Lighting);
    try app.addSystem("render.main", system.PlayerHud);

    try app.run();
}
