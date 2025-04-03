const std = @import("std");

pub const Grid = struct {
    const size: f32 = 40.0; // total size of the grid
    const resolution: u32 = 16; // number of cells along each axis (nxn)

    // derived values
    const cells_per_side = resolution;
    const vertices_per_side = resolution + 1;
    const vertex_count = vertices_per_side * vertices_per_side;

    // for filled triangles
    const triangles_per_cell = 2;
    const triangles_count = cells_per_side * cells_per_side * triangles_per_cell;
    const indices_count_filled = triangles_count * 3;

    // for wireframe - we draw lines for all horizontal and vertical grid lines
    const h_lines_count = vertices_per_side * cells_per_side; // horizontal lines
    const v_lines_count = cells_per_side * vertices_per_side; // vertical lines
    const indices_count_wireframe = (h_lines_count + v_lines_count) * 2;

    label: []const u8,
    vertices: [vertex_count * 3]f32 = undefined, // x,y,z
    colors: [vertex_count * 4]f32 = undefined, // r,g,b,a
    indices_filled: [indices_count_filled]u32 = undefined,
    indices_wireframe: [indices_count_wireframe]u32 = undefined,

    pub fn init(label: []const u8) Grid {
        var grid = Grid{
            .label = label,
        };

        grid.generateVertices();
        grid.generateIndices();

        return grid;
    }

    fn generateVertices(self: *Grid) void {
        var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        var rand = prng.random();

        const cell_size = size / @as(f32, @floatFromInt(cells_per_side));
        const half_size = size / 2.0;

        var vertex_idx: u32 = 0;
        var color_idx: u32 = 0;
        var z: u32 = 0;
        while (z < vertices_per_side) : (z += 1) {
            var x: u32 = 0;
            while (x < vertices_per_side) : (x += 1) {
                const pos_x = @as(f32, @floatFromInt(x)) * cell_size - half_size;
                const pos_z = @as(f32, @floatFromInt(z)) * cell_size - half_size;

                // generate more interesting height values using position
                const height_scale = 5.0;
                const height = (rand.float(f32) * 0.7) +
                    (0.3 * @cos(pos_x * 0.2) * @sin(pos_z * 0.2)) * height_scale;
                // const height = 0;

                self.vertices[vertex_idx + 0] = pos_x;
                self.vertices[vertex_idx + 1] = height;
                self.vertices[vertex_idx + 2] = pos_z;

                // color based on height (green to white gradient)
                const normalized_height = height / height_scale;
                self.colors[color_idx + 0] = 0.2 + normalized_height * 0.8; // r (more red at higher elevations)
                self.colors[color_idx + 1] = 0.7; // g (always some green)
                self.colors[color_idx + 2] = 0.2 + normalized_height * 0.8; // b (more blue at higher elevations)
                self.colors[color_idx + 3] = 1.0; // a (always fully opaque)

                vertex_idx += 3;
                color_idx += 4;
            }
        }
    }

    fn generateIndices(self: *Grid) void {
        // generate indices for filled triangles
        var idx_filled: u32 = 0;

        var z: u32 = 0;
        while (z < cells_per_side) : (z += 1) {
            var x: u32 = 0;
            while (x < cells_per_side) : (x += 1) {
                // calculate indices for the corners of this grid cell
                const top_left = z * vertices_per_side + x;
                const top_right = top_left + 1;
                const bottom_left = (z + 1) * vertices_per_side + x;
                const bottom_right = bottom_left + 1;

                // first triangle (top-left, bottom-left, bottom-right)
                self.indices_filled[idx_filled + 0] = @intCast(top_left);
                self.indices_filled[idx_filled + 1] = @intCast(bottom_left);
                self.indices_filled[idx_filled + 2] = @intCast(bottom_right);

                // second triangle (top-left, bottom-right, top-right)
                self.indices_filled[idx_filled + 3] = @intCast(top_left);
                self.indices_filled[idx_filled + 4] = @intCast(bottom_right);
                self.indices_filled[idx_filled + 5] = @intCast(top_right);

                idx_filled += 6;
            }
        }

        // generate indices for wireframe view
        var idx_wireframe: u32 = 0;

        // horizontal lines (z-constant lines along x-axis)
        z = 0;
        while (z < vertices_per_side) : (z += 1) {
            var x: u32 = 0;
            while (x < cells_per_side) : (x += 1) {
                const start_idx = z * vertices_per_side + x;
                const end_idx = start_idx + 1;

                self.indices_wireframe[idx_wireframe + 0] = @intCast(start_idx);
                self.indices_wireframe[idx_wireframe + 1] = @intCast(end_idx);

                idx_wireframe += 2;
            }
        }

        // vertical lines (x-constant lines along z-axis)
        var x: u32 = 0;
        while (x < vertices_per_side) : (x += 1) {
            z = 0;
            while (z < cells_per_side) : (z += 1) {
                const start_idx = z * vertices_per_side + x;
                const end_idx = start_idx + vertices_per_side;

                self.indices_wireframe[idx_wireframe + 0] = @intCast(start_idx);
                self.indices_wireframe[idx_wireframe + 1] = @intCast(end_idx);

                idx_wireframe += 2;
            }
        }
    }
};
