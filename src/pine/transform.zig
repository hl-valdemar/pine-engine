const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Quaternion = math.Quaternion;

pub const Rotation = struct {
    angle: f32 = 0,
    axis_norm: Vec3 = Vec3.up(),
};

pub const Transform = struct {
    position: Vec3 = Vec3.zeros(),
    rotation: Quaternion = Quaternion.identity(),
    scale: Vec3 = Vec3.ones(),

    pub fn getModelMatrix(self: Transform) Mat4 {
        const T = Mat4.translate(self.position);
        const R = self.rotation.toMat4();
        const S = Mat4.scale(self.scale);
        return Mat4.mul(T, Mat4.mul(R, S));
    }

    pub fn rotate(self: *Transform, axis: Vec3, angle: f32) void {
        const q = Quaternion.fromAxisAngle(axis, angle);
        self.rotation = Quaternion.mul(self.rotation, q);
    }

    pub fn setRotation(self: *Transform, axis: Vec3, angle: f32) void {
        self.rotation = Quaternion.fromAxisAngle(axis, angle);
    }
};
