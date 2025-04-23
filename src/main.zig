const std = @import("std");
const Allocator = std.mem.Allocator;

const pine = @import("pine");
const pecs = @import("pecs");
const sokol = @import("sokol");

pub const std_options = std.Options{
    .logFn = pine.log.logFn,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var app = try pine.app.App.init(allocator, .{});
    defer app.deinit();

    try app.registerSystem(EventHandlerSystem, .Update);

    app.run();
}

const EventHandlerSystem = struct {
    pub fn init(_: Allocator) anyerror!EventHandlerSystem {
        return EventHandlerSystem{};
    }

    pub fn deinit(_: *EventHandlerSystem) void {}

    pub fn process(_: *EventHandlerSystem, registry: *pecs.Registry) anyerror!void {
        var result = try registry.queryResource(pine.app.Event);
        while (result.next()) |event| {
            if (event.key_code == .ESCAPE and event.type == .KEY_UP) {
                try registry.pushResource(pine.app.Message.RequestQuit);
            }
            if (event.key_code == .ENTER and event.type == .KEY_UP) {
                std.log.info("ENTER RELEASED!", .{});
            }
            if (event.key_code == .ENTER and event.type == .KEY_DOWN) {
                std.log.info("ENTER DOWN!", .{});
            }
        }
    }
};
