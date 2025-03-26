const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Quaternion = math.Quaternion;

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

    pub fn combine(parent: Transform, child: Transform) Transform {
        // HOW? SCALE -> ROTATE -> TRANSFORM

        var result = Transform{};
        result.scale = Vec3.mul(parent.scale, child.scale);

        var rotated_position = parent.rotation.rotateVec3(child.position);
        rotated_position = Vec3.mul(rotated_position, parent.scale);

        result.position = Vec3.add(parent.position, rotated_position);
        result.rotation = Quaternion.mul(parent.rotation, child.rotation);

        return result;
    }
};
