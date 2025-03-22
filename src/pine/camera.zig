const sokol = @import("sokol");

const Transform = @import("transform.zig").Transform;

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

    pub fn init(eye: Vec3, target: Vec3, fov: f32, aspect: f32, near: f32, far: f32) Camera {
        return .{
            .fov = fov,
            .aspect = aspect,
            .near = near,
            .far = far,
            .view = Mat4.lookat(eye, target, Vec3.up()),
            .projection = Mat4.persp(fov, aspect, near, far),
        };
    }

    pub fn update(self: *Camera) void {
        self.updateAspectRatio(sokol.app.widthf() / sokol.app.heightf());
    }

    pub fn updateAspectRatio(self: *Camera, aspect: f32) void {
        self.projection = Mat4.persp(self.fov, aspect, self.near, self.far);
        self.aspect = aspect;
    }

    pub fn computeMVP(camera: *const Camera, transform: *const Transform) Mat4 {
        const model_matrix = transform.get_model_matrix();
        const view_projection = Mat4.mul(camera.projection, camera.view);
        return Mat4.mul(view_projection, model_matrix);
    }
};
