const std = @import("std");
const sokol = @import("sokol");

pub const Mesh = struct {
    allocator: std.mem.Allocator,

    vertices: []const f32,
    normals: []const f32,
    colors: []const f32,
    indices: []const u32,

    bindings: sokol.gfx.Bindings,

    label: []const u8,

    vbuf: sokol.gfx.Buffer,
    label_vbuf: []const u8,

    nbuf: sokol.gfx.Buffer,
    label_nbuf: []const u8,

    cbuf: sokol.gfx.Buffer,
    label_cbuf: []const u8,

    ibuf: sokol.gfx.Buffer,
    label_ibuf: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        label: []const u8,
        vertices: []const f32,
        normals: ?[]const f32,
        colors: ?[]const f32,
        indices: []const u32,
    ) !Mesh {
        // copy vertex data
        const v_copy = try allocator.dupe(f32, vertices);
        errdefer allocator.free(v_copy);

        const n_copy = if (normals) |n| blk: {
            const copy = try allocator.dupe(f32, n);
            break :blk copy;
        } else blk: {
            // generate flat normals if not provided
            const normal_count = (vertices.len / 3) * 3; // 3 vertex components per normal (also of 3 components)
            const auto_normals = try allocator.alloc(f32, normal_count);

            // fill with default up normals
            var i: usize = 0;
            while (i < normal_count) : (i += 3) {
                auto_normals[i + 0] = 0.0;
                auto_normals[i + 1] = 1.0;
                auto_normals[i + 2] = 0.0;
            }

            break :blk auto_normals;
        };
        errdefer allocator.free(n_copy);

        const c_copy = if (colors) |n| blk: {
            const copy = try allocator.dupe(f32, n);
            break :blk copy;
        } else blk: {
            // generate flat colors if not provided
            const color_count = (vertices.len / 3) * 4; // 3 vertex components per color (of 4 components)
            const auto_colors = try allocator.alloc(f32, color_count);

            // fill with default white colors
            var i: usize = 0;
            while (i < color_count) : (i += 4) {
                auto_colors[i + 0] = 1.0;
                auto_colors[i + 1] = 1.0;
                auto_colors[i + 2] = 1.0;
                auto_colors[i + 3] = 1.0;
            }

            break :blk auto_colors;
        };
        errdefer allocator.free(c_copy);

        // copy index data
        const i_copy = try allocator.dupe(u32, indices);
        errdefer allocator.free(i_copy);

        // create labels
        const label_prefix = try allocator.dupe(u8, label);
        errdefer allocator.free(label_prefix);

        const label_vbuf = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ label_prefix, "vertex-buffer" });
        errdefer allocator.free(label_vbuf);

        const label_nbuf = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ label_prefix, "normal-buffer" });
        errdefer allocator.free(label_nbuf);

        const label_cbuf = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ label_prefix, "color0-buffer" });
        errdefer allocator.free(label_cbuf);

        const label_ibuf = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ label_prefix, "index-buffer" });
        errdefer allocator.free(label_ibuf);

        // create sokol buffers
        const vbuf = sokol.gfx.makeBuffer(.{
            .type = .VERTEXBUFFER,
            .data = sokol.gfx.asRange(v_copy),
            .label = @ptrCast(label_vbuf),
        });
        errdefer sokol.gfx.destroyBuffer(vbuf);

        const nbuf = sokol.gfx.makeBuffer(.{
            .type = .VERTEXBUFFER,
            .data = sokol.gfx.asRange(n_copy),
            .label = @ptrCast(label_nbuf),
        });
        errdefer sokol.gfx.destroyBuffer(nbuf);

        const cbuf = sokol.gfx.makeBuffer(.{
            .type = .VERTEXBUFFER,
            .data = sokol.gfx.asRange(c_copy),
            .label = @ptrCast(label_cbuf),
        });
        errdefer sokol.gfx.destroyBuffer(cbuf);

        const ibuf = sokol.gfx.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sokol.gfx.asRange(i_copy),
            .label = @ptrCast(label_ibuf),
        });
        errdefer sokol.gfx.destroyBuffer(ibuf);

        // create bindings using the buffers
        const bindings = blk: {
            var b = sokol.gfx.Bindings{};
            b.vertex_buffers[0] = vbuf;
            b.vertex_buffers[1] = nbuf;
            b.vertex_buffers[2] = cbuf;
            b.index_buffer = ibuf;
            break :blk b;
        };

        return .{
            .allocator = allocator,

            .vertices = v_copy,
            .normals = n_copy,
            .colors = c_copy,
            .indices = i_copy,

            .bindings = bindings,
            .label = label_prefix,

            .vbuf = vbuf,
            .label_vbuf = label_vbuf,

            .nbuf = nbuf,
            .label_nbuf = label_nbuf,

            .cbuf = cbuf,
            .label_cbuf = label_cbuf,

            .ibuf = ibuf,
            .label_ibuf = label_ibuf,
        };
    }

    pub fn deinit(self: *const Mesh) void {
        sokol.gfx.destroyBuffer(self.vbuf);
        self.allocator.free(self.label_vbuf);

        sokol.gfx.destroyBuffer(self.nbuf);
        self.allocator.free(self.label_nbuf);

        sokol.gfx.destroyBuffer(self.cbuf);
        self.allocator.free(self.label_cbuf);

        sokol.gfx.destroyBuffer(self.ibuf);
        self.allocator.free(self.label_ibuf);

        self.allocator.free(self.vertices);
        self.allocator.free(self.normals);
        self.allocator.free(self.colors);
        self.allocator.free(self.indices);

        self.allocator.free(self.label);
    }
};
