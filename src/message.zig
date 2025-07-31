const WindowID = @import("pine-window").WindowID;

/// For communication inward.
pub const Message = union(enum) {
    shutdown: ShutdownReason,
    close_window: WindowID,

    pub const ShutdownReason = enum {
        requested,
    };
};
