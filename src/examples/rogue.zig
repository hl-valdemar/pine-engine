const std = @import("std");
const pine = @import("pine-engine");

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{}).init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    var app = try pine.App.init(allocator, .{});
    defer app.deinit();

    try app.addPlugin(pine.RenderTerminalPlugin);

    try app.run();
}
