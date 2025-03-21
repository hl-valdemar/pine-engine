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

pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    meshes: std.StringHashMap(Mesh),
    shaders: std.StringHashMap(Shader),
    materials: std.StringHashMap(Material),
    transforms: std.StringHashMap(Transform),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .meshes = std.StringHashMap(Mesh).init(allocator),
            .shaders = std.StringHashMap(Shader).init(allocator),
            .materials = std.StringHashMap(Material).init(allocator),
            .transforms = std.StringHashMap(Transform).init(allocator),
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

        // free transforms
        var transform_iterator = self.transforms.valueIterator();
        while (transform_iterator.next()) |t| {
            t.deinit();
        }
        self.transforms.deinit();
    }

    // MESH HANDLING //

    pub fn createMesh(
        self: *ResourceManager,
        label: []const u8,
        vertices: []const f32,
        indices: []const u16,
    ) !void {
        try self.meshes.put(label, try Mesh.init(
            self.allocator,
            label,
            vertices,
            indices,
        ));
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
        label: []const u8,
    ) ?*Mesh {
        return self.meshes.getPtr(label);
    }

    // SHADER HANDLING //

    pub fn createShader(
        self: *ResourceManager,
        label: []const u8,
        vertex_source: []const u8,
        fragment_source: []const u8,
        backend: sokol.gfx.Backend,
    ) !void {
        try self.shaders.put(label, try Shader.init(
            self.allocator,
            label,
            vertex_source,
            fragment_source,
            backend,
        ));
    }

    pub fn destroyShader(
        self: *ResourceManager,
        label: []const u8,
    ) bool {
        if (self.shaders.fetchRemove(label)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getShader(
        self: *ResourceManager,
        label: []const u8,
    ) ?*Shader {
        return self.shaders.getPtr(label);
    }

    // MATERIAL HANDLING //

    pub fn createMaterial(
        self: *ResourceManager,
        label: []const u8,
        shader_label: []const u8,
    ) !void {
        try self.materials.put(label, try Material.init(
            self.allocator,
            label,
            shader_label,
        ));
    }

    pub fn destroyMaterial(
        self: *ResourceManager,
        label: []const u8,
    ) void {
        if (self.materials.fetchRemove(label)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getMaterial(
        self: *ResourceManager,
        label: []const u8,
    ) ?*Material {
        return self.materials.getPtr(label);
    }

    // TRANSFORM HANDLING //

    pub fn createTransform(
        self: *ResourceManager,
        label: []const u8,
        position: Vec3,
        rotation: Rotation,
        scale: Vec3,
    ) !void {
        try self.transforms.put(label, .{
            .position = position,
            .rotation = rotation,
            .scale = scale,
        });
    }

    pub fn destroyTransform(
        self: *ResourceManager,
        label: []const u8,
    ) void {
        if (self.transforms.fetchRemove(label)) |entry| {
            entry.value.deinit();
            return true;
        }
        return false;
    }

    pub fn getTransform(
        self: *ResourceManager,
        label: []const u8,
    ) ?*Transform {
        return self.transforms.getPtr(label);
    }
};
