const std = @import("std");
const sokol = @import("sokol");

const Mesh = @import("mesh.zig").Mesh;
const Shader = @import("shader.zig").Shader;
const Material = @import("material.zig").Material;

const transform = @import("transform.zig");
const Transform = transform.Transform;
const Rotation = transform.Rotation;

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Quaternion = math.Quaternion;

// resource IDs
pub const UniqueIDType = u64;

// ID manager
pub const UniqueID = struct {
    pub const INVALID: UniqueIDType = 0;

    var next_id: UniqueIDType = INVALID + 1;

    pub fn generateNext() UniqueIDType {
        defer next_id += 1;
        return next_id;
    }
};

pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    meshes: std.AutoHashMap(UniqueIDType, Mesh),
    shaders: std.AutoHashMap(UniqueIDType, Shader),
    materials: std.AutoHashMap(UniqueIDType, Material),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .meshes = std.AutoHashMap(UniqueIDType, Mesh).init(allocator),
            .shaders = std.AutoHashMap(UniqueIDType, Shader).init(allocator),
            .materials = std.AutoHashMap(UniqueIDType, Material).init(allocator),
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
        indices: []const u32,
    ) !UniqueIDType {
        const new_id = UniqueID.generateNext();
        try self.meshes.put(new_id, try Mesh.init(
            self.allocator,
            label,
            vertices,
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
        id: UniqueIDType,
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
    ) !UniqueIDType {
        const new_id = UniqueID.generateNext();
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
        id: UniqueIDType,
    ) bool {
        if (self.shaders.fetchRemove(id)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getShader(
        self: *ResourceManager,
        id: UniqueIDType,
    ) ?*Shader {
        return self.shaders.getPtr(id);
    }

    // MATERIAL HANDLING //

    pub fn createMaterial(
        self: *ResourceManager,
        label: []const u8,
        shader_id: UniqueIDType,
    ) !UniqueIDType {
        const new_id = UniqueID.generateNext();
        try self.materials.put(new_id, try Material.init(
            self.allocator,
            label,
            shader_id,
        ));
        return new_id;
    }

    pub fn destroyMaterial(
        self: *ResourceManager,
        id: UniqueIDType,
    ) void {
        if (self.materials.fetchRemove(id)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getMaterial(
        self: *ResourceManager,
        id: UniqueIDType,
    ) ?*Material {
        return self.materials.getPtr(id);
    }
};
