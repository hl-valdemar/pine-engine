const std = @import("std");

pub const ExampleError = error{
    NotEnoughArguments,
    TooManyArguments,
    InvalidArgument,
    NotImplemented,
    StdOut,
};

const Args = [][:0]u8;

fn runExamples(args: Args) ExampleError!void {
    // args[0] is the program name
    // args[1] is the first argument, and so on

    if (args.len < 2) {
        return ExampleError.NotEnoughArguments;
    } else if (args.len > 2) {
        return ExampleError.TooManyArguments;
    }

    if (std.mem.eql(u8, args[1], "help")) {
        const stdout = std.io.getStdOut().writer();
        stdout.print("Run examples: `examples [example]`, or with zig build: `zig build examples -- [example]`. For a list of examples, look in the examples folder in the Pine Engine repo.\n", .{}) catch {
            return ExampleError.StdOut;
        };
    } else if (std.mem.eql(u8, args[1], "cube")) {
        try @import("cube/cube.zig").main();
    } else if (std.mem.eql(u8, args[1], "terrain")) {
        try @import("terrain/terrain.zig").main();
    } else if (std.mem.eql(u8, args[1], "grass")) {
        try @import("grass/grass.zig").main();
    } else if (std.mem.eql(u8, args[1], "instancing")) {
        try @import("instancing/instancing.zig").main();
    } else {
        return ExampleError.InvalidArgument;
    }
}

pub fn printErrMsg(msg: []const u8) !void {
    const stderr = std.io.getStdErr().writer();

    // ANSI escape codes for colors
    const red = "\x1b[31m";
    const reset = "\x1b[0m";

    try stderr.print("{s}error{s}: {s}\n", .{ red, reset, msg });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    runExamples(args) catch |err| {
        try switch (err) {
            ExampleError.NotEnoughArguments => printErrMsg("not enough arguments"),
            ExampleError.TooManyArguments => printErrMsg("too many arguments"),
            ExampleError.InvalidArgument => printErrMsg("example doesn't exist"),
            ExampleError.NotImplemented => printErrMsg("example not implemented"),
            ExampleError.StdOut => printErrMsg("failed to get handle on stdout"),
        };
    };
}
