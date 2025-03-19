const std = @import("std");
const sokol = @import("sokol");

pub const Mesh = struct {
    vbuf: sokol.gfx.Buffer,
    ibuf: sokol.gfx.Buffer,
    vertex_count: usize,
    index_count: usize,

    pub fn init(
        vertices: []const f32,
        indices: []const u16,
    ) Mesh {
        return .{
            .vertex_count = vertices.len,
            .index_count = indices.len,
            .vbuf = sokol.gfx.makeBuffer(.{
                .type = .VERTEXBUFFER,
                .data = sokol.gfx.asRange(vertices),
            }),
            .ibuf = sokol.gfx.makeBuffer(.{
                .type = .INDEXBUFFER,
                .data = sokol.gfx.asRange(indices),
            }),
        };
    }

    pub fn deinit(self: *const Mesh) void {
        sokol.gfx.destroyBuffer(self.vbuf);
        sokol.gfx.destroyBuffer(self.ibuf);
    }
};
