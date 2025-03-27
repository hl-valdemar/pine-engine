const std = @import("std");
const pine = @import("pine");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

pub const ExampleError = error{
    NotEnoughArguments,
    TooManyArguments,
    InvalidExample,
    InvalidOption,
    NotImplemented,
    StdOut,
};

const Args = [][:0]u8;

fn runExamples(args: Args) ExampleError!void {
    // args[0] is the program name
    // args[1] is the first argument, and so on

    if (args.len < 2) {
        return ExampleError.NotEnoughArguments;
    }

    if (std.mem.eql(u8, args[1], "help")) {
        if (args.len > 2) {
            return ExampleError.TooManyArguments;
        }

        const help_msg =
            \\Run examples: `examples [example] [--option]` using the binary, or with zig build: `zig build examples -- [example] [--option]`.
            \\
            \\  Examples with available options:
            \\    
            \\    cube
            \\    lighting
            \\    terrain
            \\    grass --terrain-type=[perlin,trig]
            \\    instancing
            \\
        ;

        const stdout = std.io.getStdOut().writer();
        stdout.print("{s}", .{help_msg}) catch {
            return ExampleError.StdOut;
        };
    } else if (std.mem.eql(u8, args[1], "cube")) {
        if (args.len > 2) return ExampleError.TooManyArguments;
        try @import("cube/main.zig").main();
    } else if (std.mem.eql(u8, args[1], "lighting")) {
        if (args.len > 2) return ExampleError.TooManyArguments;
        try @import("lighting//main.zig").main();
    } else if (std.mem.eql(u8, args[1], "terrain")) {
        if (args.len > 2) return ExampleError.TooManyArguments;
        try @import("terrain/main.zig").main();
    } else if (std.mem.eql(u8, args[1], "grass")) {
        if (args.len == 3) {
            if (std.mem.eql(u8, args[2], "--terrain-type=perlin")) {
                try @import("grass/main.zig").main("perlin");
            } else if (std.mem.eql(u8, args[2], "--terrain-type=trig")) {
                try @import("grass/main.zig").main("trig");
            } else {
                return ExampleError.InvalidOption;
            }
        } else if (args.len > 3) {
            return ExampleError.TooManyArguments;
        }
        try @import("grass/main.zig").main("perlin");
    } else if (std.mem.eql(u8, args[1], "instancing")) {
        if (args.len > 2) return ExampleError.TooManyArguments;
        try @import("instancing/main.zig").main();
    } else {
        return ExampleError.InvalidExample;
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
            ExampleError.InvalidExample => printErrMsg("invalid example"),
            ExampleError.InvalidOption => printErrMsg("invalid option"),
            ExampleError.NotImplemented => printErrMsg("example not implemented"),
            ExampleError.StdOut => printErrMsg("failed to get handle on stdout"),
        };
    };
}
