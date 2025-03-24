const std = @import("std");
const pine = @import("pine");

const palettes = @import("main.zig").palettes;

pub const Grid = struct {
    pub const size: f32 = 40.0; // total size of the grid
    pub const resolution: u32 = 16; // number of cells along each axis (nxn)

    // derived values
    pub const cells_per_side = resolution;
    pub const vertices_per_side = resolution + 1;
    pub const vertex_count = vertices_per_side * vertices_per_side;

    // for filled triangles
    pub const triangles_per_cell = 2;
    pub const triangles_count = cells_per_side * cells_per_side * triangles_per_cell;
    pub const indices_count_filled = triangles_count * 3;

    // for wireframe - we draw lines for all horizontal and vertical grid lines
    pub const h_lines_count = vertices_per_side * cells_per_side; // horizontal lines
    pub const v_lines_count = cells_per_side * vertices_per_side; // vertical lines
    pub const indices_count_wireframe = (h_lines_count + v_lines_count) * 2;

    label: []const u8,
    vertices: [vertex_count * 7]f32 = undefined, // x,y,z + r,g,b,a
    indices_filled: [indices_count_filled]u32 = undefined,
    indices_wireframe: [indices_count_wireframe]u32 = undefined,
    heights: [vertex_count]f32 = undefined,

    pub fn init(label: []const u8, terrain_type: []const u8) Grid {
        var grid = Grid{
            .label = label,
        };

        if (std.mem.eql(u8, terrain_type, "perlin")) {
            grid.generateVerticesPerlin();
        } else if (std.mem.eql(u8, terrain_type, "trig")) {
            grid.generateVertices();
        } else {
            std.debug.panic("UNKNOWN TERRAIN TYPE: '{s}'", .{terrain_type});
        }
        grid.generateIndices();

        return grid;
    }

    fn generateVerticesPerlin(self: *Grid) void {
        var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        var rand = prng.random();
        const noise_seed_coarse: u32 = rand.int(u32);
        // const noise_seed_fine: u32 = rand.int(u32);

        const cell_size = size / @as(f32, @floatFromInt(cells_per_side));
        const half_size = size / 2.0;

        var idx: u32 = 0;
        var vertex_idx: u32 = 0;
        var z: u32 = 0;
        while (z < vertices_per_side) : (z += 1) {
            var x: u32 = 0;
            while (x < vertices_per_side) : (x += 1) {
                const pos_x = @as(f32, @floatFromInt(x)) * cell_size - half_size;
                const pos_z = @as(f32, @floatFromInt(z)) * cell_size - half_size;

                const noise_scale_coarse = 2 / size;
                const noise_value_coarse = pine.perlin.noise(
                    noise_seed_coarse,
                    pos_x * noise_scale_coarse,
                    pos_z * noise_scale_coarse,
                );
                // const noise_scale_fine = 100 / size;
                // const noise_value_fine = perlin.noise(noise_seed_fine, pos_x * noise_scale_fine, pos_z * noise_scale_coarse);

                const height_scale = 5.0;
                const height = noise_value_coarse * height_scale;

                self.heights[vertex_idx] = height;

                self.vertices[idx + 0] = pos_x;
                self.vertices[idx + 1] = height;
                self.vertices[idx + 2] = pos_z;

                const normalized_height = height / height_scale;
                self.vertices[idx + 3] = (1 - normalized_height) * palettes.paper8.BLUE_GREEN.r + normalized_height * palettes.paper8.GREEN.r; // r (more red at higher elevations)
                self.vertices[idx + 4] = (1 - normalized_height) * palettes.paper8.BLUE_GREEN.g + normalized_height * palettes.paper8.GREEN.g; // g (always some green)
                self.vertices[idx + 5] = (1 - normalized_height) * palettes.paper8.BLUE_GREEN.b + normalized_height * palettes.paper8.GREEN.b; // b (more blue at higher elevations)
                self.vertices[idx + 6] = 1.0; // a (always fully opaque)

                idx += 7;
                vertex_idx += 1;
            }
        }
    }

    fn generateVertices(self: *Grid) void {
        var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
        var rand = prng.random();

        const cell_size = size / @as(f32, @floatFromInt(cells_per_side));
        const half_size = size / 2.0;

        var idx: u32 = 0;
        var vertex_idx: u32 = 0;
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

                self.heights[vertex_idx] = height;

                self.vertices[idx + 0] = pos_x;
                self.vertices[idx + 1] = height;
                self.vertices[idx + 2] = pos_z;

                const normalized_height = height / height_scale;
                self.vertices[idx + 3] = (1 - normalized_height) * palettes.paper8.BLUE_GREEN.r + normalized_height * palettes.paper8.GREEN.r; // r (more red at higher elevations)
                self.vertices[idx + 4] = (1 - normalized_height) * palettes.paper8.BLUE_GREEN.g + normalized_height * palettes.paper8.GREEN.g; // g (always some green)
                self.vertices[idx + 5] = (1 - normalized_height) * palettes.paper8.BLUE_GREEN.b + normalized_height * palettes.paper8.GREEN.b; // b (more blue at higher elevations)
                self.vertices[idx + 6] = 1.0; // a (always fully opaque)

                idx += 7;
                vertex_idx += 1;
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
