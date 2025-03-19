const std = @import("std");

const Mat4 = @import("math.zig").Mat4;
const Vec3 = @import("math.zig").Vec3;

pub const Camera = struct {
    position: Vec3,
    target: Vec3,
    up: Vec3,
    fov: f32,
    aspect: f32,
    near: f32,
    far: f32,
    view_matrix: Mat4,
    projection_matrix: Mat4,

    pub fn init(
        position: Vec3,
        target: Vec3,
        up: Vec3,
        fov: f32,
        aspect: f32,
        near: f32,
        far: f32,
    ) Camera {
        return .{
            .position = position,
            .target = target,
            .up = up,
            .fov = fov,
            .aspect = aspect,
            .near = near,
            .far = far,
            .view_matrix = Mat4.lookat(position, target, up),
            .projection_matrix = Mat4.persp(fov, aspect, near, far),
        };
    }

    pub fn update_view_matrix(self: *Camera) void {
        self.view_matrix = Mat4.lookat(self.position, self.target, self.up);
    }

    pub fn update_projection_matrix(
        self: *Camera,
        fov: f32,
        aspect: f32,
        near: f32,
        far: f32,
    ) void {
        self.fov = fov;
        self.aspect = aspect;
        self.near = near;
        self.far = far;
        self.projection_matrix = Mat4.persp(fov, aspect, near, far);
    }
};
