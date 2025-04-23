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

    var app = try pine.app.AppState.init(allocator, .{});
    defer app.deinit();

    try app.registerSystem(EventHandlerSystem, .Update);

    app.run();
}

const EventHandlerSystem = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) anyerror!EventHandlerSystem {
        return EventHandlerSystem{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EventHandlerSystem) void {
        _ = self;
    }

    pub fn update(self: *EventHandlerSystem, registry: *pecs.Registry) anyerror!void {
        _ = self;

        var result = try registry.queryResource(pine.app.EventType);
        while (result.next()) |event_ptr| {
            const event = event_ptr.*.*;
            if (event.key_code == .ESCAPE and event.type == .KEY_UP) {
                sokol.app.requestQuit();
            }
            if (event.key_code == .ENTER and event.type == .KEY_UP) {
                std.log.info("ENTER!", .{});
            }
        }
    }
};
