const std = @import("std");

const Transform = @import("transform.zig").Transform;
const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;

const UniqueID = @import("resource_manager.zig").UniqueID;
const UniqueIDType = @import("resource_manager.zig").UniqueIDType;

pub const Scene = struct {
    allocator: std.mem.Allocator,

    root: *SceneNode,
    nodes_by_id: std.AutoHashMap(UniqueIDType, *SceneNode),

    pub fn init(allocator: std.mem.Allocator) !Scene {
        const root = try allocator.create(SceneNode);
        root.* = try SceneNode.init(allocator, "root");

        var nodes_by_id = std.AutoHashMap(UniqueIDType, *SceneNode).init(allocator);
        try nodes_by_id.put(root.id, root);

        return .{
            .allocator = allocator,
            .root = root,
            .nodes_by_id = nodes_by_id,
        };
    }

    pub fn deinit(self: *Scene) void {
        self.root.deinit();
        self.allocator.destroy(self.root);
        self.nodes_by_id.deinit();
    }

    pub fn createNode(self: *Scene, label: []const u8) !*SceneNode {
        const node = try self.allocator.create(SceneNode);
        node.* = try SceneNode.init(self.allocator, label);
        try self.nodes_by_id.put(node.id, node);
        return node;
    }

    pub fn getNodeByUID(self: *Scene, id: UniqueIDType) ?*SceneNode {
        return self.nodes_by_id.get(id);
    }

    pub fn traverse(self: *Scene, callback: fn (*SceneNode) void) void {
        self.traverseNode(self.root, callback);
    }

    pub fn traverseNode(self: *Scene, node: *SceneNode, callback: fn (*SceneNode) void) void {
        callback(node);
        for (node.children.items) |child| {
            self.traverseNode(child, callback);
        }
    }

    pub fn traverseWithContext(
        self: *Scene,
        context: anytype,
        callback: fn (*SceneNode, @TypeOf(context)) void,
    ) void {
        self.traverseNodeWithContext(self.root, context, callback);
    }

    fn traverseNodeWithContext(
        self: *Scene,
        node: *SceneNode,
        context: anytype,
        callback: fn (*SceneNode, @TypeOf(context)) void,
    ) void {
        callback(node, context);

        for (node.children.items) |child| {
            self.traverseNodeWithContext(child, context, callback);
        }
    }
};

pub const SceneNode = struct {
    allocator: std.mem.Allocator,

    id: UniqueIDType,
    label: []const u8,

    parent: ?*SceneNode = null,
    children: std.ArrayList(*SceneNode),

    transform: Transform,
    mesh: ?*Mesh = null,
    material: ?*Material = null,

    mesh_id: UniqueIDType = UniqueID.INVALID,
    material_id: UniqueIDType = UniqueID.INVALID,

    visible: bool = true,

    pub fn init(allocator: std.mem.Allocator, label: []const u8) !SceneNode {
        const label_copy = try allocator.dupe(u8, label);

        return .{
            .allocator = allocator,
            .id = UniqueID.generateNext(),
            .label = label_copy,
            .parent = null,
            .children = std.ArrayList(*SceneNode).init(allocator),
            .transform = Transform{},
        };
    }

    pub fn deinit(self: *const SceneNode) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
        self.allocator.free(self.label);
    }

    pub fn addChild(self: *SceneNode, child: *SceneNode) !void {
        child.parent = self;
        try self.children.append(child);
    }

    pub fn removeChild(self: *SceneNode, id: UniqueID) ?*SceneNode {
        for (self.children.items, 0..) |child, i| {
            if (child.id == id) {
                const removed = self.children.swapRemove(i);
                removed.parent = null;
                return removed;
            }
        }
        return null;
    }

    pub fn getWorldTransform(self: *const SceneNode) Transform {
        var world_transform = self.transform;

        var current = self.parent;
        while (current) |parent| : (current = parent.parent) {
            world_transform = Transform.combine(parent.transform, world_transform);
        }

        return world_transform;
    }
};
