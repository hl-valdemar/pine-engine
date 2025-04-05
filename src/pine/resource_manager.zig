const std = @import("std");
const sokol = @import("sokol");

const Mesh = @import("mesh.zig").Mesh;
const Shader = @import("shader.zig").Shader;
const Material = @import("material.zig").Material;

const transform = @import("transform.zig");
const Transform = transform.Transform;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Quaternion = math.Quaternion;

// resource IDs
pub const UniqueIdDataType = u64;

// ID manager
pub const UniqueId = struct {
    pub const INVALID: UniqueIdDataType = 0;

    var next_id: UniqueIdDataType = INVALID + 1; // first valid ID

    pub fn generate() UniqueIdDataType {
        defer next_id += 1;
        return next_id;
    }
};

pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    meshes: std.AutoHashMap(UniqueIdDataType, Mesh),
    shaders: std.AutoHashMap(UniqueIdDataType, Shader),
    materials: std.AutoHashMap(UniqueIdDataType, Material),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .meshes = std.AutoHashMap(UniqueIdDataType, Mesh).init(allocator),
            .shaders = std.AutoHashMap(UniqueIdDataType, Shader).init(allocator),
            .materials = std.AutoHashMap(UniqueIdDataType, Material).init(allocator),
        };
    }

    pub fn deinit(self: *ResourceManager) void {
        // free meshes
        var mesh_iterator = self.meshes.valueIterator();
        while (mesh_iterator.next()) |m| {
            m.deinit();
        }
        self.meshes.deinit();

        // free shaders
        var shader_iterator = self.shaders.valueIterator();
        while (shader_iterator.next()) |s| {
            s.deinit();
        }
        self.shaders.deinit();

        // free materials
        var material_iterator = self.materials.valueIterator();
        while (material_iterator.next()) |m| {
            m.deinit();
        }
        self.materials.deinit();
    }

    // MESH HANDLING //

    pub fn createMesh(
        self: *ResourceManager,
        label: []const u8,
        vertices: []const f32,
        normals: ?[]const f32,
        colors: ?[]const f32,
        indices: []const u32,
    ) !UniqueIdDataType {
        const new_id = UniqueId.generate();
        try self.meshes.put(new_id, try Mesh.init(
            self.allocator,
            label,
            vertices,
            normals,
            colors,
            indices,
        ));
        return new_id;
    }

    pub fn destroyMesh(
        self: *ResourceManager,
        label: []const u8,
    ) bool {
        if (self.meshes.fetchRemove(label)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getMesh(
        self: *ResourceManager,
        id: UniqueIdDataType,
    ) ?*Mesh {
        return self.meshes.getPtr(id);
    }

    // SHADER HANDLING //

    pub fn createShader(
        self: *ResourceManager,
        label: []const u8,
        vertex_source: []const u8,
        fragment_source: []const u8,
        backend: sokol.gfx.Backend,
    ) !UniqueIdDataType {
        const new_id = UniqueId.generate();
        try self.shaders.put(new_id, try Shader.init(
            self.allocator,
            label,
            vertex_source,
            fragment_source,
            backend,
        ));
        return new_id;
    }

    pub fn destroyShader(
        self: *ResourceManager,
        id: UniqueIdDataType,
    ) bool {
        if (self.shaders.fetchRemove(id)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getShader(
        self: *ResourceManager,
        id: UniqueIdDataType,
    ) ?*Shader {
        return self.shaders.getPtr(id);
    }

    // MATERIAL HANDLING //

    pub fn createMaterial(
        self: *ResourceManager,
        label: []const u8,
    ) !UniqueIdDataType {
        const new_id = UniqueId.generate();
        try self.materials.put(new_id, try Material.init(
            self.allocator,
            label,
        ));
        return new_id;
    }

    pub fn destroyMaterial(
        self: *ResourceManager,
        id: UniqueIdDataType,
    ) void {
        if (self.materials.fetchRemove(id)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getMaterial(
        self: *ResourceManager,
        id: UniqueIdDataType,
    ) ?*Material {
        return self.materials.getPtr(id);
    }
};
