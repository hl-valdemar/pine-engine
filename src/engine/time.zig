const std = @import("std");
const ecs = @import("pine-ecs");

pub const TimeNanos = struct {
    value: i128,
};

pub const TimeMicros = struct {
    value: i64,
};

pub const TimeMillis = struct {
    value: i64,
};

pub const TimeSecs = struct {
    value: f64,
};

pub const TimingPlugin = ecs.Plugin.init("timing", struct {
    fn init(registry: *ecs.Registry) !void {
        // register time related resources
        try registry.registerResource(TimeNanos, .single);
        try registry.registerResource(TimeMicros, .single);
        try registry.registerResource(TimeMillis, .single);
        try registry.registerResource(TimeSecs, .single);

        // push initial values
        const start_time_nanos = std.time.nanoTimestamp();
        try registry.pushResource(TimeNanos{
            .value = start_time_nanos,
        });
        try registry.pushResource(TimeMicros{
            .value = @intCast(@divTrunc(start_time_nanos, 1_000)),
        });
        try registry.pushResource(TimeMillis{
            .value = @intCast(@divTrunc(start_time_nanos, 1_000_000)),
        });
        try registry.pushResource(TimeSecs{
            .value = @as(f64, @floatFromInt(elapsedTimeNanos(start_time_nanos))) / 1_000_000_000.0,
        });

        // register systems
        try registry.addSystem("update.post", TimeTrackSystem);
    }

    const TimeTrackSystem = struct {
        pub fn process(_: *TimeTrackSystem, registry: *ecs.Registry) anyerror!void {
            // update nanos
            const time_nanos = switch (try registry.queryResource(TimeNanos)) {
                .single => |time| time,
                .collection => unreachable,
            };
            // do this last, so that we may use time_nanos to update resources of less precision
            defer if (time_nanos.resource) |*nanos| {
                nanos.value = elapsedTimeNanos(nanos.value);
            };

            // update secs
            const time_secs = switch (try registry.queryResource(TimeSecs)) {
                .single => |time| time,
                .collection => unreachable,
            };
            if (time_secs.resource) |*secs| {
                if (time_nanos.resource) |nanos| {
                    secs.value = elapsedTimeSecs(nanos.value);
                }
            }

            // update millis
            const time_millis = switch (try registry.queryResource(TimeMillis)) {
                .single => |time| time,
                .collection => unreachable,
            };
            if (time_millis.resource) |*millis| {
                if (time_nanos.resource) |nanos| {
                    millis.value = elapsedTimeMillis(nanos.value);
                }
            }

            // update micros
            const time_micros = switch (try registry.queryResource(TimeMicros)) {
                .single => |time| time,
                .collection => unreachable,
            };
            if (time_micros.resource) |*micros| {
                if (time_nanos.resource) |nanos| {
                    micros.value = elapsedTimeMicros(nanos.value);
                }
            }
        }
    };
}.init);

pub fn elapsedTimeNanos(start_time_nanos: i128) i128 {
    return std.time.nanoTimestamp() - start_time_nanos;
}

pub fn elapsedTimeMicros(start_time_nanos: i128) i64 {
    return @intCast(@divTrunc(elapsedTimeNanos(start_time_nanos), 1_000));
}

pub fn elapsedTimeMillis(start_time_nanos: i128) i64 {
    return @intCast(@divTrunc(elapsedTimeNanos(start_time_nanos), 1_000_000));
}

pub fn elapsedTimeSecs(start_time_nanos: i128) f64 {
    return @as(f64, @floatFromInt(elapsedTimeNanos(start_time_nanos))) / 1_000_000_000.0;
}
