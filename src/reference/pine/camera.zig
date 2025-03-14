const std = @import("std");

const Mat4 = @import("utils.zig").Mat4;

pub const Camera = struct {
    view_matrix: Mat4,
    projection_matrix: Mat4,

    pub fn create_perspective(fov: f32, aspect: f32, near: f32, far: f32) Camera {
        const f = 1.0 / std.math.tan(fov * 0.5);
        const nf = 1.0 / (near - far);

        var projection = Mat4.zeros();
        projection.m[0][0] = f / aspect;
        projection.m[1][1] = f;
        projection.m[2][2] = (far + near) * nf;
        projection.m[2][3] = -1.0;
        projection.m[3][2] = 2.0 * far * near * nf;

        return .{
            .view_matrix = Mat4.identity(),
            .projection_matrix = projection,
        };
    }
};
