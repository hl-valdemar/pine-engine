/// Schedule systems.
pub const Schedule = enum {
    /// Run once on app initialization.
    init,

    /// Run once on app initialization (after init).
    post_init,

    /// Run once on app deinitialization.
    deinit,

    /// Run every tick (before update).
    ///
    /// Note: Pine generates events in this stage.
    pre_update,

    /// Run every tick.
    ///
    /// Note: the user is expected to generate messages in this stage.
    update,

    /// Run every tick (after update).
    ///
    /// Note: the system gets a chance to react to user generated messages in this stage.
    post_update,

    /// Run every tick (after update cycle).
    render,

    /// Return a string representation of the schedule value.
    pub fn toString(self: Schedule) []const u8 {
        return @tagName(self);
    }
};
