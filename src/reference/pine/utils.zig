const std = @import("std");

const expect = std.testing.expect;
const expect_equal = std.testing.expectEqual;

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn zeros() Vec2 {
        return .{ .x = 0, .y = 0 };
    }

    pub fn ones() Vec2 {
        return .{ .x = 1, .y = 1 };
    }

    pub fn add(left: Vec2, right: Vec2) Vec2 {
        return .{
            .x = left.x + right.x,
            .y = left.y + right.y,
        };
    }

    pub fn sub(left: Vec2, right: Vec2) Vec2 {
        return .{
            .x = left.x - right.x,
            .y = left.y - right.y,
        };
    }

    pub fn scale(v: Vec2, s: f32) Vec2 {
        return .{
            .x = v.x * s,
            .y = v.y * s,
        };
    }

    pub fn norm(v: Vec2) Vec2 {
        const l = v.len();
        if (l != 0) return .{
            .x = v.x / l,
            .y = v.y / l,
        } else return Vec2.zeros();
    }

    pub fn len(v: Vec2) f32 {
        return @sqrt(Vec2.dot(v, v));
    }

    pub fn dot(v1: Vec2, v2: Vec2) f32 {
        return v1.x * v2.x + v1.y * v2.y;
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn zeros() Vec3 {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn ones() Vec3 {
        return .{ .x = 1, .y = 1, .z = 1 };
    }

    pub fn up() Vec3 {
        return .{ .x = 0, .y = 1, .z = 0 };
    }

    pub fn add(left: Vec3, right: Vec3) Vec3 {
        return .{
            .x = left.x + right.x,
            .y = left.y + right.y,
            .z = left.z + right.z,
        };
    }

    pub fn sub(left: Vec3, right: Vec3) Vec3 {
        return .{
            .x = left.x - right.x,
            .y = left.y - right.y,
            .z = left.z - right.z,
        };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{
            .x = v.x * s,
            .y = v.y * s,
            .z = v.z * s,
        };
    }

    pub fn norm(v: Vec3) Vec3 {
        const l = v.len();
        if (l != 0) return .{
            .x = v.x / l,
            .y = v.y / l,
            .z = v.z / l,
        } else return Vec3.zeros();
    }

    pub fn len(v: Vec3) f32 {
        return @sqrt(Vec3.dot(v, v));
    }

    pub fn dot(v1: Vec3, v2: Vec3) f32 {
        return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z;
    }

    pub fn cross(v1: Vec3, v2: Vec3) Vec3 {
        return .{
            .x = (v1.y * v2.z) - (v1.z * v2.y),
            .y = (v1.z * v2.x) - (v1.x * v2.z),
            .z = (v1.x * v2.y) - (v1.y * v2.x),
        };
    }

    pub fn rotate(p: Vec3, q: Quaternion) Vec3 {
        // convert point to quaternion
        const p_quat = Quaternion{ .w = 0, .v = p };

        // apply q * p * q^-1 rotation
        const q_conj = Quaternion.conjugate(q);
        const temp = Quaternion.mul(q, p_quat);
        const rotated = Quaternion.mul(temp, q_conj);

        return rotated.v;
    }
};

pub const Mat4 = extern struct {
    m: [4][4]f32,

    pub fn identity() Mat4 {
        return .{ .m = [_][4]f32{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        } };
    }

    pub fn zeros() Mat4 {
        return .{ .m = [_][4]f32{
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        } };
    }

    pub fn mul(left: Mat4, right: Mat4) Mat4 {
        var res = Mat4.zeros();
        for (0..4) |row| {
            for (0..4) |col| {
                for (0..4) |k| {
                    res.m[row][col] += left.m[row][k] * right.m[k][col];
                }
            }
        }
        return res;
    }

    // rotation matrix creation helper functions
    pub fn rotation_x(angle_radians: f32) Mat4 {
        const c = @cos(angle_radians);
        const s = @sin(angle_radians);

        var mat = Mat4.identity();
        mat.m[1][1] = c;
        mat.m[1][2] = -s;
        mat.m[2][1] = s;
        mat.m[2][2] = c;
        return mat;
    }

    pub fn rotation_y(angle_radians: f32) Mat4 {
        const c = @cos(angle_radians);
        const s = @sin(angle_radians);

        var mat = Mat4.identity();
        mat.m[0][0] = c;
        mat.m[0][2] = s;
        mat.m[2][0] = -s;
        mat.m[2][2] = c;
        return mat;
    }

    pub fn rotation_z(angle_radians: f32) Mat4 {
        const c = @cos(angle_radians);
        const s = @sin(angle_radians);

        var mat = Mat4.identity();
        mat.m[0][0] = c;
        mat.m[0][1] = -s;
        mat.m[1][0] = s;
        mat.m[1][1] = c;
        return mat;
    }

    pub fn translation(position: Vec3) Mat4 {
        var mat = Mat4.identity();
        mat.m[0][3] = position.x;
        mat.m[1][3] = position.y;
        mat.m[2][3] = position.z;
        return mat;
    }

    pub fn scaling(scale: Vec3) Mat4 {
        var mat = Mat4.identity();
        mat.m[0][0] = scale.x;
        mat.m[1][1] = scale.y;
        mat.m[2][2] = scale.z;
        return mat;
    }

    // applying a matrix to a vector
    pub fn transform_point(self: Mat4, point: Vec3) Vec3 {
        return .{
            .x = self.m[0][0] * point.x + self.m[0][1] * point.y + self.m[0][2] * point.z + self.m[0][3],
            .y = self.m[1][0] * point.x + self.m[1][1] * point.y + self.m[1][2] * point.z + self.m[1][3],
            .z = self.m[2][0] * point.x + self.m[2][1] * point.y + self.m[2][2] * point.z + self.m[2][3],
        };
    }

    // create perspective projection matrix
    pub fn perspective(fov_y_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const tan_half_fovy = @tan(fov_y_radians / 2);

        var result = Mat4.zeros();
        result.m[0][0] = 1.0 / (aspect * tan_half_fovy);
        result.m[1][1] = 1.0 / tan_half_fovy;
        result.m[2][2] = -(far + near) / (far - near);
        result.m[2][3] = -(2.0 * far * near) / (far - near);
        result.m[3][2] = -1.0;

        return result;
    }

    // create look-at view matrix
    pub fn look_at(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        const f = Vec3.norm(Vec3.sub(target, eye));
        const s = Vec3.norm(Vec3.cross(f, up));
        const u = Vec3.cross(s, f);

        var result = Mat4.identity();
        result.m[0][0] = s.x;
        result.m[0][1] = s.y;
        result.m[0][2] = s.z;
        result.m[1][0] = u.x;
        result.m[1][1] = u.y;
        result.m[1][2] = u.z;
        result.m[2][0] = -f.x;
        result.m[2][1] = -f.y;
        result.m[2][2] = -f.z;
        result.m[0][3] = -Vec3.dot(s, eye);
        result.m[1][3] = -Vec3.dot(u, eye);
        result.m[2][3] = Vec3.dot(f, eye);

        return result;
    }
};

pub const Quaternion = struct {
    w: f32, // scalar part
    v: Vec3, // vector part

    pub fn identity() Quaternion {
        return .{
            .w = 1,
            .v = .{ .x = 0, .y = 0, .z = 0 },
        };
    }

    pub fn mul(left: Quaternion, right: Quaternion) Quaternion {
        return .{
            .w = left.w * right.w - Vec3.dot(left.v, right.v),
            .v = Vec3.add(
                Vec3.add(
                    Vec3.scale(right.v, left.w),
                    Vec3.scale(left.v, right.w),
                ),
                Vec3.cross(left.v, right.v),
            ),
        };
    }

    pub fn conjugate(q: Quaternion) Quaternion {
        return .{
            .w = q.w,
            .v = .{
                .x = -q.v.x,
                .y = -q.v.y,
                .z = -q.v.z,
            },
        };
    }

    pub fn norm(q: Quaternion) f32 {
        return @sqrt(q.w * q.w + Vec3.dot(q.v, q.v));
    }

    pub fn normalize(q: Quaternion) Quaternion {
        const mag = Quaternion.norm(q);
        if (mag < 0.000001) return Quaternion.identity(); // avoid division by zero
        return .{
            .w = q.w / mag,
            .v = Vec3.scale(q.v, 1 / mag),
        };
    }

    pub fn from_vec(v: Vec3) Quaternion {
        return .{ .w = 0, .v = v };
    }

    // Create quaternion from euler angles (radians)
    pub fn from_euler(x: f32, y: f32, z: f32) Quaternion {
        const cx = @cos(x * 0.5);
        const sx = @sin(x * 0.5);
        const cy = @cos(y * 0.5);
        const sy = @sin(y * 0.5);
        const cz = @cos(z * 0.5);
        const sz = @sin(z * 0.5);

        return .{
            .w = cx * cy * cz + sx * sy * sz,
            .v = .{
                .x = sx * cy * cz - cx * sy * sz,
                .y = cx * sy * cz + sx * cy * sz,
                .z = cx * cy * sz - sx * sy * cz,
            },
        };
    }

    // Create quaternion from axis-angle
    pub fn from_axis_angle(axis: Vec3, angle: f32) Quaternion {
        const half_angle = angle * 0.5;
        const s = @sin(half_angle);
        const normalized_axis = Vec3.norm(axis);

        return .{
            .w = @cos(half_angle),
            .v = Vec3.scale(normalized_axis, s),
        };
    }

    // Convert quaternion to rotation matrix
    pub fn to_rotation_matrix(q: Quaternion) Mat4 {
        const qn = Quaternion.normalize(q);
        const x = qn.v.x;
        const y = qn.v.y;
        const z = qn.v.z;
        const w = qn.w;

        const x2 = x * x;
        const y2 = y * y;
        const z2 = z * z;
        const xy = x * y;
        const xz = x * z;
        const yz = y * z;
        const wx = w * x;
        const wy = w * y;
        const wz = w * z;

        var mat = Mat4.identity();

        mat.m[0][0] = 1 - 2 * (y2 + z2);
        mat.m[0][1] = 2 * (xy - wz);
        mat.m[0][2] = 2 * (xz + wy);

        mat.m[1][0] = 2 * (xy + wz);
        mat.m[1][1] = 1 - 2 * (x2 + z2);
        mat.m[1][2] = 2 * (yz - wx);

        mat.m[2][0] = 2 * (xz - wy);
        mat.m[2][1] = 2 * (yz + wx);
        mat.m[2][2] = 1 - 2 * (x2 + y2);

        return mat;
    }
};

test "Mat4 multiplication correctness" {
    // Identity tests
    const id = Mat4.identity();
    try expect_equal(Mat4.mul(id, id), id);

    // Basic test matrices
    const m1 = Mat4{ .m = [_][4]f32{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    } };

    const m2 = Mat4{ .m = [_][4]f32{
        .{ 17, 18, 19, 20 },
        .{ 21, 22, 23, 24 },
        .{ 25, 26, 27, 28 },
        .{ 29, 30, 31, 32 },
    } };

    // Test matrix multiplication
    const result = Mat4.mul(m1, m2);

    // Check specific elements based on row-major matrix multiplication
    try expect_equal(result.m[0][0], 250);
    try expect_equal(result.m[0][1], 260);
    try expect_equal(result.m[0][2], 270);
    try expect_equal(result.m[0][3], 280);

    try expect_equal(result.m[1][0], 618);
    try expect_equal(result.m[2][0], 986);
    try expect_equal(result.m[3][0], 1354);

    // Test with transformation matrices
    const translate = Mat4.translation(Vec3{ .x = 10, .y = 20, .z = 30 });
    const scale = Mat4.scaling(Vec3{ .x = 2, .y = 3, .z = 4 });
    const rotate_x = Mat4.rotation_x(std.math.pi / 2.0); // 90 degrees

    // Transform a point
    const point = Vec3{ .x = 1, .y = 2, .z = 3 };

    // Scale then translate
    const st_matrix = Mat4.mul(translate, scale);
    const st_point = st_matrix.transform_point(point);
    try expect_equal(st_point.x, 12); // 1*2 + 10
    try expect_equal(st_point.y, 26); // 2*3 + 20
    try expect_equal(st_point.z, 42); // 3*4 + 30

    // Rotate around X by 90 degrees (y->z, z->-y)
    const rotated_point = rotate_x.transform_point(point);
    try expect(@abs(rotated_point.x - 1) < 0.0001);
    try expect(@abs(rotated_point.y - (-3)) < 0.0001);
    try expect(@abs(rotated_point.z - 2) < 0.0001);
}

test "Quaternion rotation correctness" {
    // Unit quaternions for 90 degree rotations
    const q_x = Quaternion.from_axis_angle(Vec3{ .x = 1, .y = 0, .z = 0 }, std.math.pi / 2.0);
    const q_y = Quaternion.from_axis_angle(Vec3{ .x = 0, .y = 1, .z = 0 }, std.math.pi / 2.0);
    const q_z = Quaternion.from_axis_angle(Vec3{ .x = 0, .y = 0, .z = 1 }, std.math.pi / 2.0);

    // Test points
    const point_x = Vec3{ .x = 1, .y = 0, .z = 0 };
    const point_y = Vec3{ .x = 0, .y = 1, .z = 0 };
    const point_z = Vec3{ .x = 0, .y = 0, .z = 1 };

    // Rotating x-axis around x-axis should keep it the same
    const rotated_x_around_x = Vec3.rotate(point_x, q_x);
    try expect(@abs(rotated_x_around_x.x - 1) < 0.0001);
    try expect(@abs(rotated_x_around_x.y) < 0.0001);
    try expect(@abs(rotated_x_around_x.z) < 0.0001);

    // Rotating y-axis around x-axis by 90 degrees should give z-axis
    const rotated_y_around_x = Vec3.rotate(point_y, q_x);
    try expect(@abs(rotated_y_around_x.x) < 0.0001);
    try expect(@abs(rotated_y_around_x.y) < 0.0001);
    try expect(@abs(rotated_y_around_x.z - 1) < 0.0001);

    // Rotating z-axis around x-axis by 90 degrees should give negative y-axis
    const rotated_z_around_x = Vec3.rotate(point_z, q_x);
    try expect(@abs(rotated_z_around_x.x) < 0.0001);
    try expect(@abs(rotated_z_around_x.y + 1) < 0.0001);
    try expect(@abs(rotated_z_around_x.z) < 0.0001);

    // Test composition of rotations: rotate around x then around y
    const q_xy = Quaternion.mul(q_y, q_x); // This is correct, the order matters!

    // Rotating z-axis with the composed rotation
    const rotated_z_xy = Vec3.rotate(point_z, q_xy);

    // For rotating z-axis with q_xy (x then y rotations of 90 degrees):
    // First x rotation takes (0,0,1) to (0,-1,0)
    // Then y rotation takes (0,-1,0) to (0,-1,0) (no change in this case)
    try expect(@abs(rotated_z_xy.x) < 0.0001);
    try expect(@abs(rotated_z_xy.y + 1) < 0.0001); // y should be approximately -1
    try expect(@abs(rotated_z_xy.z) < 0.0001);

    // Equivalent rotation matrix composition test
    const rot_mat_x = Mat4.rotation_x(std.math.pi / 2.0);
    const rot_mat_y = Mat4.rotation_y(std.math.pi / 2.0);
    const rot_mat_xy = Mat4.mul(rot_mat_y, rot_mat_x);

    const rotated_z_matrix = rot_mat_xy.transform_point(point_z);

    try expect(@abs(rotated_z_matrix.x) < 0.0001);
    try expect(@abs(rotated_z_matrix.y) < 0.0001);
    try expect(@abs(rotated_z_matrix.z + 1) < 0.0001);

    // Verify quaternion and matrix rotations give consistent results
    const quat_result = Vec3.rotate(point_x, q_z);
    const matrix_result = Mat4.rotation_z(std.math.pi / 2.0).transform_point(point_x);

    try expect(@abs(quat_result.x - matrix_result.x) < 0.0001);
    try expect(@abs(quat_result.y - matrix_result.y) < 0.0001);
    try expect(@abs(quat_result.z - matrix_result.z) < 0.0001);
}
