const std = @import("std");
const Mesh = @import("mesh.zig").Mesh;

pub const ResourceType = enum {
    mesh,
};

pub const Resource = union(ResourceType) {
    mesh: struct {
        label: []const u8,
        data: Mesh,
    },
};

pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    resources: std.StringHashMap(Resource),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .resources = std.StringHashMap(Resource).init(allocator),
        };
    }

    pub fn deinit(self: *ResourceManager) void {
        var it = self.resources.valueIterator();
        while (it.next()) |resource| {
            switch (resource.*) {
                .mesh => |*m| {
                    self.allocator.free(m.label);
                    m.data.deinit();
                },
            }
        }
        self.resources.deinit();
    }

    /// Creates a mesh from the given data and stores it with the label.
    pub fn createMesh(
        self: *ResourceManager,
        label: []const u8,
        vertices: []const f32,
        indices: []const u16,
    ) !void {
        try self.resources.put(label, .{
            .mesh = .{
                .label = try self.allocator.dupe(u8, label),
                .data = try Mesh.init(self.allocator, vertices, indices),
            },
        });
    }

    /// Returns the mesh corresponding to the label if found, and null otherwise.
    pub fn getMesh(self: *ResourceManager, label: []const u8) ?*Resource {
        if (self.resources.getPtr(label)) |resource| {
            return resource;
        }
        return null;
    }

    /// Destroys the mesh with the given label.
    ///
    /// Returns true if the entry existed and was destroyed, and false otherwise.
    pub fn destroyMesh(
        self: *ResourceManager,
        label: []const u8,
    ) bool {
        if (self.resources.fetchRemove(label)) |entry| {
            self.destroyResource(.mesh, entry.value);
            return true;
        }
        return false;
    }

    /// Destroys the given resource.
    ///
    /// Precondition: the given resource type corresponds correctly to the resource.
    fn destroyResource(self: *ResourceManager, resource_type: ResourceType, resource: Resource) void {
        switch (resource_type) {
            .mesh => {
                self.allocator.free(resource.mesh.label);
                resource.mesh.data.deinit();
            },
        }
    }
};
