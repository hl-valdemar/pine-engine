const std = @import("std");
const sokol = @import("sokol");

pub const Vertex = struct {
    position: [3]f32,
    color: [4]f32,

    pub fn get_vertex_layout() sokol.gfx.VertexLayoutState {
        var layout = sokol.gfx.VertexLayoutState{};
        layout.attrs[0] = .{ .format = .FLOAT3, .offset = @offsetOf(Vertex, "position") };
        layout.attrs[1] = .{ .format = .FLOAT4, .offset = @offsetOf(Vertex, "color") };
        return layout;
    }
};

pub const Mesh = struct {
    allocator: std.mem.Allocator,
    vertices: []Vertex,
    indices: []u16,
    vbuf: sokol.gfx.Buffer,
    ibuf: sokol.gfx.Buffer,

    pub fn init(allocator: std.mem.Allocator, vertices: []const Vertex, indices: []const u16) !*Mesh {
        // NOTE: WHY DO IT LIKE THIS?
        var mesh = try allocator.create(Mesh);

        mesh.allocator = allocator;

        // copy vertex and index data
        mesh.*.vertices = try allocator.dupe(Vertex, vertices);
        mesh.*.indices = try allocator.dupe(u16, indices);

        // create sokol buffers
        mesh.vbuf = sokol.gfx.makeBuffer(.{
            .type = .VERTEXBUFFER,
            .data = sokol.gfx.asRange(mesh.vertices),
        });
        mesh.ibuf = sokol.gfx.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sokol.gfx.asRange(mesh.indices),
        });

        return mesh;
    }

    pub fn deinit(self: *Mesh) void {
        self.allocator.destroy(self);
    }

    pub fn create_triangle_mesh(allocator: std.mem.Allocator) !*Mesh {
        const vertices = [_]Vertex{
            .{ .position = .{ -0.5, -0.5, 0.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
            .{ .position = .{ 0.5, -0.5, 0.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
            .{ .position = .{ 0.0, 0.5, 0.0 }, .color = .{ 0.0, 0.0, 1.0, 1.0 } },
        };
        const indices = [_]u16{ 0, 1, 2 };

        return Mesh.init(allocator, &vertices, &indices);
    }
};
