const std = @import("std");
const sokol = @import("sokol");

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    vertices: []const f32,
    indices: []const u16,
    vbuf: sokol.gfx.Buffer,
    ibuf: sokol.gfx.Buffer,

    /// Precondition: sokol is initialized.
    pub fn init(
        allocator: std.mem.Allocator,
        vertices: []const f32,
        indices: []const u16,
    ) !Mesh {
        const v_copy = try allocator.dupe(f32, vertices);
        const i_copy = try allocator.dupe(u16, indices);

        return .{
            .allocator = allocator,
            .vertices = v_copy,
            .indices = i_copy,
            .vbuf = sokol.gfx.makeBuffer(.{
                .type = .VERTEXBUFFER,
                .data = sokol.gfx.asRange(v_copy),
            }),
            .ibuf = sokol.gfx.makeBuffer(.{
                .type = .INDEXBUFFER,
                .data = sokol.gfx.asRange(i_copy),
            }),
        };
    }

    pub fn deinit(self: *const Mesh) void {
        sokol.gfx.destroyBuffer(self.vbuf);
        sokol.gfx.destroyBuffer(self.ibuf);
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
    }
};
