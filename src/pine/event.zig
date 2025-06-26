const WindowID = @import("window.zig").WindowID;

const c = @cImport(@cInclude("GLFW/glfw3.h"));

pub const Modifier = struct {
    pub const Type = c_int;

    pub const NONE = 0;
    pub const SHIFT = c.GLFW_MOD_SHIFT;
};

/// For communication outward.
pub const Event = union(enum) {
    keyEvent: struct {
        key: Key,
        state: KeyState,

        /// Originating window.
        window_id: WindowID,
        modifiers: Modifier.Type = Modifier.NONE,
    },
};

pub const Key = enum(c_int) {
    Escape = c.GLFW_KEY_ESCAPE,
    Enter = c.GLFW_KEY_ENTER,
    Space = c.GLFW_KEY_SPACE,
};

pub const KeyState = enum {
    Pressed,
    JustPressed,
    Released,
    JustReleased,
};
