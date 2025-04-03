pub const Cube = struct {
    // for a cube, we need 36 vertices (6 faces * 2 triangles * 3 vertices)
    pub const VERTICES = [_]f32{
        // Back face (negative z)
        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        -1.0, 1.0,  -1.0,

        // Front face (positive z)
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  1.0,

        // Left face (negative x)
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  -1.0,
        -1.0, 1.0,  1.0,
        -1.0, -1.0, 1.0,

        // Right face (positive x)
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        1.0,  1.0,  1.0,
        1.0,  -1.0, 1.0,

        // Bottom face (negative y)
        -1.0, -1.0, -1.0,
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        1.0,  -1.0, -1.0,

        // Top face (positive y)
        -1.0, 1.0,  -1.0,
        -1.0, 1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  -1.0,
    };

    pub const NORMALS = [_]f32{
        // Back face (negative z)
        0,  0,  -1,
        0,  0,  -1,
        0,  0,  -1,
        0,  0,  -1,

        // Front face (positive z)
        0,  0,  1,
        0,  0,  1,
        0,  0,  1,
        0,  0,  1,

        // Left face (negative x)
        -1, 0,  0,
        -1, 0,  0,
        -1, 0,  0,
        -1, 0,  0,

        // Right face (positive x)
        1,  0,  0,
        1,  0,  0,
        1,  0,  0,
        1,  0,  0,

        // Bottom face (negative y)
        0,  -1, 0,
        0,  -1, 0,
        0,  -1, 0,
        0,  -1, 0,

        // Top face (positive y)
        0,  1,  0,
        0,  1,  0,
        0,  1,  0,
        0,  1,  0,
    };

    // white
    pub const COLORS = [_]f32{
        // Back face (negative z)
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,

        // Front face (positive z)
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,

        // Left face (negative x)
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,

        // Right face (positive x)
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,

        // Bottom face (negative y)
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,

        // Top face (positive y)
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
        1, 1, 1, 1,
    };

    pub const INDICES = [_]u32{
        0,  1,  2,
        0,  2,  3,

        6,  5,  4,
        7,  6,  4,

        8,  9,  10,
        8,  10, 11,

        14, 13, 12,
        15, 14, 12,

        16, 17, 18,
        16, 18, 19,

        22, 21, 20,
        23, 22, 20,
    };
};
