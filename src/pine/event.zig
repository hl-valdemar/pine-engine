const glfw = @import("glfw");

const WindowID = @import("window.zig").WindowID;

pub const Modifier = struct {
    pub const Type = u32;

    pub const LEFT_SHIFT = 0b0001;
    pub const RIGHT_SHIFT = 0b0010;
};

/// For communication outward.
pub const Event = union(enum) {
    keyEvent: struct {
        key: Key,
        state: KeyState,

        /// Originating window.
        window_id: WindowID,
        modifiers: Modifier.Type = 0,
    },
};

pub const Key = enum(glfw.Key) {
    Escape = glfw.KeyEscape,
    Enter = glfw.KeyEnter,
};

pub const KeyState = enum {
    Pressed,
    JustPressed,
    Released,
    JustReleased,
};
