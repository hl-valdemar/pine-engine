/// Schedule systems.
pub const Schedule = enum {
    /// Run once on app initialization.
    Init,

    /// Run once on app deinitialization.
    Deinit,

    /// Run every tick (before Update).
    ///
    /// Note: Pine generates events in this stage.
    PreUpdate,

    /// Run every tick.
    ///
    /// Note: the user is expected to generate messages in this stage.
    Update,

    /// Run every tick (after Update).
    ///
    /// Note: the system gets a chance to react to user generated messages in this stage.
    PostUpdate,

    /// Run every tick (after update cycle).
    Render,

    /// Return a string representation of the schedule value.
    pub fn toString(self: Schedule) []const u8 {
        return @tagName(self);
    }
};
