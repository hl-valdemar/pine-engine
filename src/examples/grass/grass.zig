const std = @import("std");
const pine = @import("pine");

const palettes = @import("palettes.zig").palettes;

const Grid = @import("terrain.zig").Grid;

pub const Grass = struct {
    const max_blades_per_cell = 400;
    const max_blade_count = Grid.cells_per_side * Grid.cells_per_side * max_blades_per_cell;
    const vertices_per_blade = 6;
    const vertex_count = max_blade_count * vertices_per_blade;
    const indices_per_blade = 12;
    const index_count = max_blade_count * indices_per_blade;
    const min_height = 0.8;
    const max_height = 1.8;
    const blade_width = 0.1;
    const bend_point = 0.6;
    const min_bend_angle = 10;
    const max_bend_angle = 40;

    var blades_total: u32 = 0;

    pub var vertices: [vertex_count * 7]f32 = undefined;
    pub var indices: [index_count]u32 = undefined;

    label: []const u8,

    pub fn init(label: []const u8, grid: *const Grid) Grass {
        var grass = Grass{
            .label = label,
        };

        grass.generate(grid);

        return grass;
    }

    fn generate(self: *Grass, grid: *const Grid) void {
        _ = self;

        var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp() + 42))); // Different seed from terrain
        var rand = prng.random();
        const noise_seed_coarse: u32 = @intCast(rand.int(u32));
        const noise_seed_fine: u32 = @intCast(rand.int(u32));

        const cell_size = Grid.size / @as(f32, @floatFromInt(Grid.cells_per_side));
        const half_size = Grid.size / 2.0;

        var vertex_idx: u32 = 0;
        var index_idx: u32 = 0;
        var total_blades: u32 = 0;

        var cell_z: u32 = 0;
        while (cell_z < Grid.cells_per_side) : (cell_z += 1) {
            var cell_x: u32 = 0;
            while (cell_x < Grid.cells_per_side) : (cell_x += 1) {
                // Define the terrain cell corners
                const top_left_idx = cell_z * Grid.vertices_per_side + cell_x;
                const top_right_idx = top_left_idx + 1;
                const bottom_left_idx = (cell_z + 1) * Grid.vertices_per_side + cell_x;
                const bottom_right_idx = bottom_left_idx + 1;

                // Get the heights at each corner
                const top_left_height = grid.heights[top_left_idx];
                const top_right_height = grid.heights[top_right_idx];
                const bottom_left_height = grid.heights[bottom_left_idx];
                const bottom_right_height = grid.heights[bottom_right_idx];

                // Calculate base position of the cell in world coordinates
                const base_x = @as(f32, @floatFromInt(cell_x)) * cell_size - half_size;
                const base_z = @as(f32, @floatFromInt(cell_z)) * cell_size - half_size;

                // Use Perlin noise to determine grass density in this cell
                const noise_scale_coarse = 1000 / Grid.size;
                const noise_value_coarse = pine.perlin.noise(noise_seed_coarse, base_x * noise_scale_coarse, base_z * noise_scale_coarse);
                const density_coarse = (noise_value_coarse + 1.0) / 2.0; // Normalize to 0-1

                // Scale the number of blades based on noise (e.g., 0 to blades_per_cell)
                const blade_count = @as(
                    u32,
                    @intFromFloat(density_coarse * @as(
                        f32,
                        @floatFromInt(max_blades_per_cell),
                    )),
                );

                // Generate multiple grass blades per cell
                var blade: u32 = 0;
                var blades_placed: u32 = 0;
                while (blade < blade_count and total_blades < max_blade_count) : (blade += 1) {
                    // Check if we've exceeded our array capacity
                    if (vertex_idx + 7 * vertices_per_blade > vertex_count * 7 or
                        index_idx + indices_per_blade > index_count)
                    {
                        break;
                    }

                    // Interpolate within the cell to position the grass blade
                    const offset_x = rand.float(f32) * cell_size;
                    const offset_z = rand.float(f32) * cell_size;
                    const pos_x = base_x + offset_x;
                    const pos_z = base_z + offset_z;

                    // Sample noise at blade position
                    const noise_scale_fine = 100 / Grid.size;
                    const noise_value_fine = pine.perlin.noise(
                        noise_seed_fine,
                        pos_x * noise_scale_fine,
                        pos_z * noise_scale_fine,
                    );
                    const density_fine = (noise_value_fine + 1.0) / 2.0;

                    // Only place blade if density exceeds a threshold
                    if (density_fine < 0.3) continue;

                    // Base vertex index for this blade - record the index of the first vertex in this blade
                    const base_vertex_idx = vertex_idx / 7;

                    // Compute the exact height at this position using bilinear interpolation
                    const x_pct = offset_x / cell_size;
                    const z_pct = offset_z / cell_size;
                    const top_interp = top_left_height * (1.0 - x_pct) + top_right_height * x_pct;
                    const bottom_interp = bottom_left_height * (1.0 - x_pct) + bottom_right_height * x_pct;
                    const height = top_interp * (1.0 - z_pct) + bottom_interp * z_pct;

                    // Random blade height between min and max
                    const blade_height = min_height + rand.float(f32) * (max_height - min_height);

                    // Random blade rotation (around Y axis) for variation
                    const angle = rand.float(f32) * std.math.pi * 2.0;
                    const half_width = blade_width * 0.5;

                    // Compute the offset vectors for the base of the blade
                    const offset_x1 = @cos(angle) * half_width;
                    const offset_z1 = @sin(angle) * half_width;
                    const offset_x2 = @cos(angle + std.math.pi) * half_width;
                    const offset_z2 = @sin(angle + std.math.pi) * half_width;

                    // Bend parameters
                    const bend_height = height + blade_height * bend_point;
                    const bend_angle_rad = (min_bend_angle + rand.float(f32) *
                        (max_bend_angle - min_bend_angle)) * (std.math.pi / 180.0);

                    // Tilt direction for the blade
                    const tilt_angle = angle + std.math.pi * 0.5; // Perpendicular to width
                    const tilt_x = @cos(tilt_angle);
                    const tilt_z = @sin(tilt_angle);

                    // Calculate the positions with bend
                    const bend_offset_magnitude = blade_height * (1.0 - bend_point) * @sin(bend_angle_rad);
                    const upper_section_height = blade_height * (1.0 - bend_point) * @cos(bend_angle_rad);

                    const bend_offset_x = tilt_x * bend_offset_magnitude;
                    const bend_offset_z = tilt_z * bend_offset_magnitude;

                    // Create the six vertices that define the bent grass blade:

                    // Vertex 0: Bottom left
                    vertices[vertex_idx + 0] = pos_x + offset_x1; // x
                    vertices[vertex_idx + 1] = height; // y
                    vertices[vertex_idx + 2] = pos_z + offset_z1; // z
                    // Color - darker green at base
                    vertices[vertex_idx + 3] = palettes.paper8.BLUE_GREEN.r; // r
                    vertices[vertex_idx + 4] = palettes.paper8.BLUE_GREEN.g; // g
                    vertices[vertex_idx + 5] = palettes.paper8.BLUE_GREEN.b; // b
                    vertices[vertex_idx + 6] = 1.0; // a
                    vertex_idx += 7;

                    // Vertex 1: Bottom right
                    vertices[vertex_idx + 0] = pos_x + offset_x2; // x
                    vertices[vertex_idx + 1] = height; // y
                    vertices[vertex_idx + 2] = pos_z + offset_z2; // z
                    // Color - darker green at base
                    vertices[vertex_idx + 3] = palettes.paper8.BLUE_GREEN.r; // r
                    vertices[vertex_idx + 4] = palettes.paper8.BLUE_GREEN.g; // g
                    vertices[vertex_idx + 5] = palettes.paper8.BLUE_GREEN.b; // b
                    vertices[vertex_idx + 6] = 1.0; // a
                    vertex_idx += 7;

                    // Vertex 2: Middle left (at bend point)
                    vertices[vertex_idx + 0] = pos_x + offset_x1; // x
                    vertices[vertex_idx + 1] = bend_height; // y
                    vertices[vertex_idx + 2] = pos_z + offset_z1; // z
                    // Color - medium green at middle
                    const mid_green_r = (palettes.paper8.BLUE_GREEN.r + 1.0) * 0.5;
                    const mid_green_g = (palettes.paper8.BLUE_GREEN.g + 1.0) * 0.5;
                    const mid_green_b = (palettes.paper8.BLUE_GREEN.b + 1.0) * 0.5;
                    vertices[vertex_idx + 3] = mid_green_r; // r
                    vertices[vertex_idx + 4] = mid_green_g; // g
                    vertices[vertex_idx + 5] = mid_green_b; // b
                    vertices[vertex_idx + 6] = 1.0; // a
                    vertex_idx += 7;

                    // Vertex 3: Middle right (at bend point)
                    vertices[vertex_idx + 0] = pos_x + offset_x2; // x
                    vertices[vertex_idx + 1] = bend_height; // y
                    vertices[vertex_idx + 2] = pos_z + offset_z2; // z
                    // Color - medium green at middle
                    vertices[vertex_idx + 3] = mid_green_r; // r
                    vertices[vertex_idx + 4] = mid_green_g; // g
                    vertices[vertex_idx + 5] = mid_green_b; // b
                    vertices[vertex_idx + 6] = 1.0; // a
                    vertex_idx += 7;

                    // Vertex 4: Top left (tip after bend)
                    vertices[vertex_idx + 0] = pos_x + offset_x1 + bend_offset_x; // x
                    vertices[vertex_idx + 1] = bend_height + upper_section_height; // y
                    vertices[vertex_idx + 2] = pos_z + offset_z1 + bend_offset_z; // z
                    // Color - lighter green at tip
                    const blade_height_normalized = blade_height / max_height;
                    const tip_green_r = (1 - blade_height_normalized) * mid_green_r + blade_height_normalized * palettes.paper8.YELLOW_LIGHT.r;
                    const tip_green_g = (1 - blade_height_normalized) * mid_green_g + blade_height_normalized * palettes.paper8.YELLOW_LIGHT.g;
                    const tip_green_b = (1 - blade_height_normalized) * mid_green_b + blade_height_normalized * palettes.paper8.YELLOW_LIGHT.b;
                    vertices[vertex_idx + 3] = tip_green_r; // r
                    vertices[vertex_idx + 4] = tip_green_g; // g
                    vertices[vertex_idx + 5] = tip_green_b; // b
                    vertices[vertex_idx + 6] = 1.0; // a
                    vertex_idx += 7;

                    // Vertex 5: Top right (tip after bend)
                    vertices[vertex_idx + 0] = pos_x + offset_x2 + bend_offset_x; // x
                    vertices[vertex_idx + 1] = bend_height + upper_section_height; // y
                    vertices[vertex_idx + 2] = pos_z + offset_z2 + bend_offset_z; // z
                    // Color - lighter green at tip
                    vertices[vertex_idx + 3] = tip_green_r; // r
                    vertices[vertex_idx + 4] = tip_green_g; // g
                    vertices[vertex_idx + 5] = tip_green_b; // b
                    vertices[vertex_idx + 6] = 1.0; // a
                    vertex_idx += 7;

                    // Create indices for two triangles in the lower part (forming a quad)
                    indices[index_idx + 0] = @intCast(base_vertex_idx); // Bottom left
                    indices[index_idx + 1] = @intCast(base_vertex_idx + 1); // Bottom right
                    indices[index_idx + 2] = @intCast(base_vertex_idx + 3); // Middle right

                    indices[index_idx + 3] = @intCast(base_vertex_idx); // Bottom left
                    indices[index_idx + 4] = @intCast(base_vertex_idx + 3); // Middle right
                    indices[index_idx + 5] = @intCast(base_vertex_idx + 2); // Middle left

                    // Create indices for two triangles in the upper part (forming a quad)
                    indices[index_idx + 6] = @intCast(base_vertex_idx + 2); // Middle left
                    indices[index_idx + 7] = @intCast(base_vertex_idx + 3); // Middle right
                    indices[index_idx + 8] = @intCast(base_vertex_idx + 5); // Top right

                    indices[index_idx + 9] = @intCast(base_vertex_idx + 2); // Middle left
                    indices[index_idx + 10] = @intCast(base_vertex_idx + 5); // Top right
                    indices[index_idx + 11] = @intCast(base_vertex_idx + 4); // Top left

                    index_idx += 12;
                    blades_placed += 1;
                    total_blades += 1;
                }
            }
        }

        // Update the static counter
        blades_total = total_blades;

        // If we need to debug, uncomment this
        // std.debug.print("Generated {} grass blades with {} vertices and {} indices\n",
        //     .{ total_blades, vertex_idx / 7, index_idx });
    }
};
