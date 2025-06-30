const WindowID = @import("pine-window").WindowID;

/// For communication inward.
pub const Message = union(enum) {
    /// Special as this value is checked explicitly in the update loop.
    shutdown: ShutdownReason,
    close_window: WindowID,
};

pub const ShutdownReason = enum {
    requested,
};
