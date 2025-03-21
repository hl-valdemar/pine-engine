const std = @import("std");
const sokol = @import("sokol");

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    vertices: []const f32,
    indices: []const u16,
    vbuf: sokol.gfx.Buffer,
    ibuf: sokol.gfx.Buffer,
    bindings: sokol.gfx.Bindings,
    label: []const u8,
    label_vbuf: []const u8,
    label_ibuf: []const u8,

    /// Precondition: sokol is initialized.
    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        vertices: []const f32,
        indices: []const u16,
    ) !Mesh {
        const v_copy = try allocator.dupe(f32, vertices);
        errdefer allocator.free(v_copy);

        const i_copy = try allocator.dupe(u16, indices);
        errdefer allocator.free(i_copy);

        const label_prefix = try allocator.dupe(u8, label);
        errdefer allocator.free(label_prefix);

        const label_vbuf = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ label_prefix, "vertex-buffer" });
        errdefer allocator.free(label_prefix);

        const label_ibuf = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ label_prefix, "index-buffer" });
        errdefer allocator.free(label_prefix);

        const vbuf = sokol.gfx.makeBuffer(.{
            .type = .VERTEXBUFFER,
            .data = sokol.gfx.asRange(v_copy),
            .label = @ptrCast(label_vbuf),
        });
        errdefer sokol.gfx.destroyBuffer(vbuf);

        const ibuf = sokol.gfx.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sokol.gfx.asRange(i_copy),
            .label = @ptrCast(label_ibuf),
        });
        errdefer sokol.gfx.destroyBuffer(ibuf);

        const bindings = blk: {
            var b = sokol.gfx.Bindings{};
            b.vertex_buffers[0] = vbuf;
            b.index_buffer = ibuf;
            break :blk b;
        };

        return .{
            .allocator = allocator,
            .vertices = v_copy,
            .indices = i_copy,
            .vbuf = vbuf,
            .ibuf = ibuf,
            .bindings = bindings,
            .label = label_prefix,
            .label_vbuf = label_vbuf,
            .label_ibuf = label_ibuf,
        };
    }

    pub fn deinit(self: *const Mesh) void {
        sokol.gfx.destroyBuffer(self.vbuf);
        sokol.gfx.destroyBuffer(self.ibuf);
        self.allocator.free(self.vertices);
        self.allocator.free(self.indices);
        self.allocator.free(self.label);
        self.allocator.free(self.label_vbuf);
        self.allocator.free(self.label_ibuf);
    }
};
