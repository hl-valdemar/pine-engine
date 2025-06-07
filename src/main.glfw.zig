const std = @import("std");
const glfw = @import("glfw");

pub fn main() !void {
    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW {}.{}.{}\n", .{ major, minor, rev });

    try glfw.init();
    defer glfw.terminate();
    std.debug.print("GLFW init succeeded!\n", .{});

    const window = try glfw.createWindow(500, 500, "Pine Test", null, null);
    defer glfw.destroyWindow(window);

    while (true) {}

    // while (!glfw.windowShouldClose(window)) {
    //     if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
    //         glfw.setWindowShouldClose(window, true);
    //     }
    //
    //     glfw.pollEvents();
    // }
}
