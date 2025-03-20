const math = @import("math.zig");
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;

pub const Camera = struct {
    fov: f32,
    aspect: f32,
    near: f32,
    far: f32,
    view: Mat4,
    projection: Mat4,

    pub fn init(fov: f32, aspect: f32, near: f32, far: f32) Camera {
        return .{
            .fov = fov,
            .aspect = aspect,
            .near = near,
            .far = far,
            .view = Mat4.lookat(
                Vec3.with(0, 1.5, 6),
                Vec3.zeros(),
                Vec3.up(),
            ),
            .projection = Mat4.persp(fov, aspect, near, far),
        };
    }

    pub fn updateAspectRatio(self: *Camera, aspect: f32) void {
        self.projection = Mat4.persp(self.fov, aspect, self.near, self.far);
        self.aspect = aspect;
    }
};
