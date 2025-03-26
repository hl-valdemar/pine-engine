const std = @import("std");

const Transform = @import("transform.zig").Transform;
const Mesh = @import("mesh.zig").Mesh;
const Material = @import("material.zig").Material;

// static id counter
const UniqueID = u64;
var next_id: UniqueID = 0;

pub fn generateUID() u64 {
    defer next_id += 1;
    return next_id;
}

pub const SceneNode = struct {
    allocator: std.mem.Allocator,

    id: u64,
    label: []const u8,

    parent: ?*SceneNode = null,
    children: std.ArrayList(*SceneNode),

    transform: Transform,
    mesh: ?*Mesh = null,
    material: ?*Material = null,

    visible: bool = true,

    pub fn init(allocator: std.mem.Allocator, label: []const u8) SceneNode {
        const label_copy = allocator.dupe(u8, label);

        return .{
            .allocator = allocator,
            .id = generateUID(),
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
