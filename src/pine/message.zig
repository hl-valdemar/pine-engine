const WindowID = @import("window.zig").WindowID;

/// For communication inward.
pub const Message = union(enum) {
    /// Special as this value is checked explicitly in the update loop.
    Shutdown: ShutdownReason,
    CloseWindow: WindowID,
};

pub const ShutdownReason = enum {
    Requested,
};

