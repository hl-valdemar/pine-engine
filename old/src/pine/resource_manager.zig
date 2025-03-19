const std = @import("std");
const sokol = @import("sokol");

const mesh = @import("mesh.zig");
const Mesh = mesh.Mesh;

const material = @import("material.zig");
const Material = material.Material;

pub const ResourceType = enum {
    Mesh,
    Shader,
    Material,
};

pub const ResourceLabel = []const u8;

pub const Resource = union(ResourceType) {
    Mesh: Mesh,
    Shader: sokol.gfx.Shader,
    Material: Material,
};

pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    resources: std.StringHashMap(Resource),
    resource_labels: std.ArrayList(ResourceLabel),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .resources = std.StringHashMap(Resource).init(allocator),
            .resource_labels = std.ArrayList(ResourceLabel).init(allocator),
        };
    }

    pub fn deinit(self: *ResourceManager) void {
        var it = self.resources.iterator();
        while (it.next()) |entry| {
            // free resource based on type
            switch (entry.value_ptr.*) {
                .Mesh => |*m| m.deinit(),
                .Shader => |s| sokol.gfx.destroyShader(s),
                .Material => |*m| m.deinit(),
            }
        }
        self.resources.deinit();
        self.resource_labels.deinit();
    }

    pub fn addMesh(
        self: *ResourceManager,
        label: ResourceLabel,
        vertices: []const f32,
        indices: []const u16,
    ) !void {
        std.log.debug("copying label", .{});
        const label_copy = try self.allocator.dupe(u8, label);
        std.log.debug("adding label to resource labels", .{});
        try self.resource_labels.append(label_copy);

        std.log.debug("adding mesh to resources", .{});
        try self.resources.put(label_copy, Resource{
            .Mesh = Mesh.init(vertices, indices),
        });
    }

    pub fn getMesh(self: *ResourceManager, label: ResourceLabel) ?*Mesh {
        if (self.resources.getEntry(label)) |item| {
            return &item.value_ptr.Mesh;
        }
        return null;
    }
};
