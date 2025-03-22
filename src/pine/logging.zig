const std = @import("std");

pub fn log_fn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const stderr = std.io.getStdErr().writer();
    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    // consistent prefix with level and scope
    const prefix = "[" ++ comptime message_level.asText() ++ "] (" ++ @tagName(scope) ++ "): ";
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub const log = std.log.scoped(.pine);
