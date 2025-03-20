const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub const Rotation = struct {
    angle: f32 = 0,
    axis_norm: Vec3 = Vec3.up(),
};

pub const Transform = struct {
    position: Vec3 = Vec3.zeros(),
    // TODO: use quaternions for rotations instead of matrices
    rotation: Rotation = .{},
    scale: Vec3 = Vec3.ones(),

    // NOTE: noop
    pub fn deinit(self: *Transform) void {
        _ = self;
    }

    pub fn get_model_matrix(self: Transform) Mat4 {
        const T = Mat4.translate(self.position);
        const R = Mat4.rotate(self.rotation.angle, self.rotation.axis_norm);
        const S = Mat4.scale(self.scale);
        return Mat4.mul(T, Mat4.mul(R, S));
    }
};
