const std = @import("std");

const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;

const utils = @import("utils.zig");
const Vec3 = utils.Vec3;
const Mat4 = utils.Mat4;
const Quaternion = utils.Quaternion;

pub const Scene = struct {
    allocator: std.mem.Allocator,
    root: *SceneNode,

    pub fn init(allocator: std.mem.Allocator) !Scene {
        const root = try SceneNode.init(allocator, "root-scene");

        return .{
            .allocator = allocator,
            .root = root,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.root.deinit();
    }

    pub fn update(self: *Scene) void {
        // update all world transforms starting from the root
        self.root.update_world_transform(null);
    }
};

pub const SceneNode = struct {
    allocator: std.mem.Allocator,
    label: []const u8,
    transform: Transform,
    mesh: ?*Mesh = null,
    material: ?*Material = null,
    children: std.ArrayList(*SceneNode),
    parent: ?*SceneNode = null,

    pub fn init(allocator: std.mem.Allocator, label: []const u8) !*SceneNode {
        const node = try allocator.create(SceneNode);
        node.* = .{
            .allocator = allocator,
            .label = label,
            .transform = .{
                .position = Vec3.zeros(),
                .rotation = Quaternion.identity(),
                .scale = Vec3.ones(),
            },
            .children = std.ArrayList(*SceneNode).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *SceneNode) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
        self.allocator.destroy(self);
    }

    pub fn add_child(self: *SceneNode, child: *SceneNode) void {
        self.children.append(child) catch unreachable;
        child.parent = self;
    }

    pub fn update_world_transform(self: *SceneNode, parent_world_matrix: ?Mat4) void {
        // calculate local matrix
        const local_matrix = self.transform.compute_local_matrix();

        // apply parent matrix if it exists
        if (parent_world_matrix) |parent_matrix| {
            self.transform.world_matrix = Mat4.mul(parent_matrix, local_matrix);
        } else {
            self.transform.world_matrix = local_matrix;
        }

        // update children
        for (self.children.items) |child| {
            child.update_world_transform(self.transform.world_matrix);
        }
    }
};

pub const Transform = struct {
    position: Vec3,
    rotation: Quaternion,
    scale: Vec3,

    world_matrix: Mat4 = undefined,

    pub fn compute_world_matrix(self: *Transform, parent_world_matrix: ?Mat4) Mat4 {
        // calculate the local transformation matrix
        const local_matrix = self.compute_local_matrix();

        // if there's a parent world matrix, multiply with it
        if (parent_world_matrix) |parent_matrix| {
            self.world_matrix = Mat4.mul(parent_matrix, local_matrix);
        } else {
            // no parent, so local = world
            self.world_matrix = local_matrix;
        }

        return self.world_matrix;
    }

    pub fn compute_local_matrix(self: *Transform) Mat4 {
        // create scale matrix
        var scale_mat = Mat4.identity();
        scale_mat.m[0][0] = self.scale.x;
        scale_mat.m[1][1] = self.scale.y;
        scale_mat.m[2][2] = self.scale.z;

        // create rotation matrix from quaternion
        const rot_mat = self.rotation.to_rotation_matrix();

        // create translation matrix
        var trans_mat = Mat4.identity();
        trans_mat.m[3][0] = self.position.x;
        trans_mat.m[3][1] = self.position.y;
        trans_mat.m[3][2] = self.position.z;

        // combine matrices: translation * rotation * scale
        return Mat4.mul(Mat4.mul(trans_mat, rot_mat), scale_mat);
    }
};
