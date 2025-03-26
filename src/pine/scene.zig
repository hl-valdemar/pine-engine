const std = @import("std");

const Transform = @import("transform.zig").Transform;
const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;

const UniqueID = @import("resource_manager.zig").UniqueID;
const UniqueIDType = @import("resource_manager.zig").UniqueIDType;

pub const SceneVisitor = struct {
    visitFn: *const fn (self: *SceneVisitor, node: *SceneNode) void,

    pub fn visit(self: *SceneVisitor, node: *SceneNode) void {
        self.visitFn(self, node);
    }

    // generic method to create a visitor from any type with a visitNode method
    pub fn init(comptime T: type) SceneVisitor {
        const visitNodeFn = struct {
            fn visit(visitor: *SceneVisitor, node: *SceneNode) void {
                const self: *T = @fieldParentPtr("visitor", visitor);
                self.visitNode(node);
            }
        }.visit;

        return .{
            .visitFn = visitNodeFn,
        };
    }
};

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

    pub fn accept(self: *Scene, visitor: *SceneVisitor) void {
        self.acceptNode(self.root, visitor);
    }

    pub fn acceptNode(self: *Scene, node: *SceneNode, visitor: *SceneVisitor) void {
        visitor.visit(node);

        for (node.children.items) |child| {
            self.acceptNode(child, visitor);
        }
    }

    pub fn acceptFiltered(
        self: *Scene,
        visitor: *SceneVisitor,
        filter: *const fn (*SceneNode) bool,
    ) void {
        self.acceptNodeFiltered(self.root, visitor, filter);
    }

    pub fn acceptNodeFiltered(
        self: *Scene,
        node: *SceneNode,
        visitor: *SceneVisitor,
        filter: *const fn (*SceneNode) bool,
    ) void {
        if (filter(node)) {
            visitor.visit(node);
        }

        for (node.children.items) |child| {
            self.acceptNodeFiltered(child, visitor, filter);
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
