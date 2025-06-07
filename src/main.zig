const std = @import("std");
const Allocator = std.mem.Allocator;

const pine = @import("pine");

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var app = try pine.app.App.init(allocator, .{});
    defer app.deinit();

    try app.addPlugin(pine.app.WindowPlugin);

    app.run();
}
