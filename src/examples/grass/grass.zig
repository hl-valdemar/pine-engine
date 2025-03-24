const std = @import("std");
const pine = @import("pine");
const sokol = @import("sokol");

pub const std_options = std.Options{
    .logFn = pine.logging.log_fn,
};

const palettes = struct {
    pub const basic = struct {
        pub const BLACK: sokol.gfx.Color = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1,
        };
        pub const LIGHT_BLUE: sokol.gfx.Color = .{
            .r = 0.5,
            .g = 0.7,
            .b = 0.9,
            .a = 1,
        };
    };

    pub const paper8 = struct {
        pub const BLUE_DARK: sokol.gfx.Color = .{
            .r = 0.122,
            .g = 0.141,
            .b = 0.294,
            .a = 1,
        };
        pub const MAGENTA_PINK_DARK: sokol.gfx.Color = .{
            .r = 0.396,
            .g = 0.251,
            .b = 0.325,
            .a = 1,
        };
        pub const RED: sokol.gfx.Color = .{
            .r = 0.659,
            .g = 0.376,
            .b = 0.365,
            .a = 1,
        };
        pub const ORANGE: sokol.gfx.Color = .{
            .r = 0.82,
            .g = 0.651,
            .b = 0.494,
            .a = 1,
        };
        pub const YELLOW_LIGHT: sokol.gfx.Color = .{
            .r = 0.965,
            .g = 0.906,
            .b = 0.612,
            .a = 1,
        };
        pub const CYAN: sokol.gfx.Color = .{
            .r = 0.235,
            .g = 0.42,
            .b = 0.392,
            .a = 1,
        };
        pub const BLUE_GREEN: sokol.gfx.Color = .{
            .r = 0.376,
            .g = 0.682,
            .b = 0.482,
            .a = 1,
        };
        pub const GREEN: sokol.gfx.Color = .{
            .r = 0.714,
            .g = 0.812,
            .b = 0.557,
            .a = 1,
        };
    };

    pub const ice_cream_gb = struct {
        pub const PINK_DARK: sokol.gfx.Color = .{
            .r = 0.486,
            .g = 0.247,
            .b = 0.345,
            .a = 1,
        };
        pub const RED: sokol.gfx.Color = .{
            .r = 0.922,
            .g = 0.42,
            .b = 0.435,
            .a = 1,
        };
        pub const ORANGE: sokol.gfx.Color = .{
            .r = 0.976,
            .g = 0.659,
            .b = 0.459,
            .a = 1,
        };
        pub const GRAYISH_YELLOW_LIGHT: sokol.gfx.Color = .{
            .r = 1,
            .g = 0.965,
            .b = 0.827,
            .a = 1,
        };
    };
};

const Grid = struct {
    const size: f32 = 40.0; // Total size of the grid
    const resolution: u32 = 16; // Number of cells along each axis (NxN)

    // Derived values
    const cells_per_side = resolution;
    const vertices_per_side = resolution + 1;
    const vertex_count = vertices_per_side * vertices_per_side;

    // For filled triangles
    const triangles_per_cell = 2;
    const triangles_count = cells_per_side * cells_per_side * triangles_per_cell;
    const indices_count_filled = triangles_count * 3;

    // For wireframe - we draw lines for all horizontal and vertical grid lines
    const h_lines_count = vertices_per_side * cells_per_side; // Horizontal lines
    const v_lines_count = cells_per_side * vertices_per_side; // Vertical lines
    const indices_count_wireframe = (h_lines_count + v_lines_count) * 2;

    label: []const u8,
    vertices: [vertex_count * 7]f32 = undefined, // x,y,z + r,g,b,a
    indices_filled: [indices_count_filled]u32 = undefined,
    indices_wireframe: [indices_count_wireframe]u32 = undefined,
    heights: [vertex_count]f32 = undefined,

    pub fn init(label: []const u8) Grid {
        var grid = Grid{
            .label = label,
        };

        grid.generateVerticesPerlin();
        grid.generateIndices();

        return grid;
    }

    fn generateVerticesPerlin(self: *Grid) void {
        // Random number generator
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
                // Calculate vertex position
                const pos_x = @as(f32, @floatFromInt(x)) * cell_size - half_size;
                const pos_z = @as(f32, @floatFromInt(z)) * cell_size - half_size;

                // Generate more interesting height values using position
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

                // const height = (rand.float(f32) * 0.7) +
                //     (0.3 * @cos(pos_x * 0.2) * @sin(pos_z * 0.2)) * height_scale;

                self.heights[vertex_idx] = height;

                // Position (x, y, z)
                self.vertices[idx + 0] = pos_x;
                self.vertices[idx + 1] = height;
                self.vertices[idx + 2] = pos_z;

                // Color based on height (green to white gradient)
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
        var z: u32 = 0;
        while (z < vertices_per_side) : (z += 1) {
            var x: u32 = 0;
            while (x < vertices_per_side) : (x += 1) {
                // Calculate vertex position
                const pos_x = @as(f32, @floatFromInt(x)) * cell_size - half_size;
                const pos_z = @as(f32, @floatFromInt(z)) * cell_size - half_size;

                // Generate more interesting height values using position
                const height_scale = 5.0;
                const height = (rand.float(f32) * 0.7) +
                    (0.3 * @cos(pos_x * 0.2) * @sin(pos_z * 0.2)) * height_scale;
                // const height = 0;

                // Position (x, y, z)
                self.vertices[idx + 0] = pos_x;
                self.vertices[idx + 1] = height;
                self.vertices[idx + 2] = pos_z;

                // Color based on height (green to white gradient)
                const normalized_height = height / height_scale;
                self.vertices[idx + 3] = 0.2 + normalized_height * 0.8; // r (more red at higher elevations)
                self.vertices[idx + 4] = 0.7; // g (always some green)
                self.vertices[idx + 5] = 0.2 + normalized_height * 0.8; // b (more blue at higher elevations)
                self.vertices[idx + 6] = 1.0; // a (always fully opaque)

                // grid.vertices[idx + 3] = 1.0;
                // grid.vertices[idx + 4] = 1.0;
                // grid.vertices[idx + 5] = 1.0;
                // grid.vertices[idx + 6] = 1.0;

                idx += 7;
            }
        }
    }

    fn generateIndices(self: *Grid) void {
        // Generate indices for filled triangles
        var idx_filled: u32 = 0;

        var z: u32 = 0;
        while (z < cells_per_side) : (z += 1) {
            var x: u32 = 0;
            while (x < cells_per_side) : (x += 1) {
                // Calculate indices for the corners of this grid cell
                const top_left = z * vertices_per_side + x;
                const top_right = top_left + 1;
                const bottom_left = (z + 1) * vertices_per_side + x;
                const bottom_right = bottom_left + 1;

                // First triangle (top-left, bottom-left, bottom-right)
                self.indices_filled[idx_filled + 0] = @intCast(top_left);
                self.indices_filled[idx_filled + 1] = @intCast(bottom_left);
                self.indices_filled[idx_filled + 2] = @intCast(bottom_right);

                // Second triangle (top-left, bottom-right, top-right)
                self.indices_filled[idx_filled + 3] = @intCast(top_left);
                self.indices_filled[idx_filled + 4] = @intCast(bottom_right);
                self.indices_filled[idx_filled + 5] = @intCast(top_right);

                idx_filled += 6;
            }
        }

        // Generate indices for wireframe (grid lines)
        var idx_wireframe: u32 = 0;

        // Horizontal lines (z-constant lines along x-axis)
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

        // Vertical lines (x-constant lines along z-axis)
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

const Grass = struct {
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

    var vertices: [vertex_count * 7]f32 = undefined;
    var indices: [index_count]u32 = undefined;

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

const WorldState = struct {
    allocator: std.mem.Allocator,
    resource_manager: pine.ResourceManager,
    camera: pine.Camera,
    renderer: pine.Renderer,
    grid: Grid,
    grass: Grass,

    pub fn init(allocator: std.mem.Allocator) WorldState {
        const camera = pine.Camera.init(
            pine.math.Vec3.with(40, 30, 40),
            pine.math.Vec3.zeros(),
            60,
            4 / 3,
            0.01,
            100,
        );

        const grid = Grid.init("terrain-grid");
        const grass = Grass.init("terrain-grass", &grid);

        return .{
            .allocator = allocator,
            .resource_manager = pine.ResourceManager.init(allocator),
            .camera = camera,
            .renderer = pine.Renderer.init(allocator, camera),
            .grid = grid,
            .grass = grass,
        };
    }

    pub fn deinit(self: *WorldState) void {
        self.resource_manager.deinit();
        self.renderer.deinit();

        // important
        sokol.gfx.shutdown();
    }

    pub fn run(self: *WorldState) void {
        sokol.app.run(sokol.app.Desc{
            .init_userdata_cb = sokolInitGrassExample,
            .frame_userdata_cb = sokolFrameGrassExample,
            .event_userdata_cb = sokolEventGrassExample,
            .user_data = self,
            .logger = .{ .func = sokol.log.func },
            .icon = .{ .sokol_default = true },
            .sample_count = 4,
            .width = 4 * 300,
            .height = 3 * 300,
            .window_title = "Pine: Grass Example",
        });
    }

    export fn sokolInitGrassExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            sokol.gfx.setup(.{
                .environment = sokol.glue.environment(),
                .logger = .{ .func = sokol.log.func },
            });

            self.resource_manager.createMesh(
                self.grid.label,
                &self.grid.vertices,
                &self.grid.indices_filled,
            ) catch |err| {
                std.log.err("failed to create terrain mesh: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MESH!\n");
            };
            self.resource_manager.createMesh(
                self.grass.label,
                &Grass.vertices,
                &Grass.indices,
            ) catch |err| {
                std.log.err("failed to create grass mesh: {}", .{err});
                @panic("FAILED TO CREATE GRASS MESH!\n");
            };

            self.resource_manager.createShader(
                self.grid.label,
                @embedFile("shaders/terrain.vs.metal"),
                @embedFile("shaders/terrain.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create terrain shader: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN SHADER!\n");
            };
            self.resource_manager.createShader(
                self.grass.label,
                @embedFile("shaders/grass.vs.metal"),
                @embedFile("shaders/grass.fs.metal"),
                sokol.gfx.queryBackend(),
            ) catch |err| {
                std.log.err("failed to create grass shader: {}", .{err});
                @panic("FAILED TO CREATE GRASS SHADER!\n");
            };

            self.resource_manager.createTransform(
                self.grid.label,
                pine.math.Vec3.zeros(),
                .{},
                pine.math.Vec3.ones(),
            ) catch |err| {
                std.log.err("failed to create terrain transform: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN TRANSFORM!\n");
            };
            self.resource_manager.createTransform(
                self.grass.label,
                pine.math.Vec3.zeros(),
                .{},
                pine.math.Vec3.ones(),
            ) catch |err| {
                std.log.err("failed to create grass transform: {}", .{err});
                @panic("FAILED TO CREATE GRASS TRANSFORM!\n");
            };

            self.resource_manager.createMaterial(self.grid.label, self.grid.label) catch |err| {
                std.log.err("failed to create terrain material: {}", .{err});
                @panic("FAILED TO CREATE TERRAIN MATERIAL!\n");
            };
            self.resource_manager.createMaterial(self.grass.label, self.grass.label) catch |err| {
                std.log.err("failed to create grass material: {}", .{err});
                @panic("FAILED TO CREATE GRASS MATERIAL!\n");
            };
        }
    }

    export fn sokolFrameGrassExample(world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));

            const dt = sokol.app.frameDuration();

            // apply rotation
            const terrain_transform = if (self.resource_manager.getTransform(self.grid.label)) |transform| blk: {
                transform.rotation.angle += @floatCast(dt * 10);
                break :blk transform;
            } else blk: {
                break :blk null;
            };
            const grass_transform = if (self.resource_manager.getTransform(self.grass.label)) |transform| blk: {
                transform.rotation.angle += @floatCast(dt * 10);
                break :blk transform;
            } else blk: {
                break :blk null;
            };

            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh(self.grid.label),
                .transform = terrain_transform,
                .material = self.resource_manager.getMaterial(self.grid.label),
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };
            self.renderer.addRenderCommand(.{
                .mesh = self.resource_manager.getMesh(self.grass.label),
                .transform = grass_transform,
                .material = self.resource_manager.getMaterial(self.grass.label),
            }) catch |err| {
                std.log.err("failed to add render command: {}", .{err});
            };

            self.renderer.render(&self.resource_manager);
        }
    }

    export fn sokolEventGrassExample(ev: [*c]const sokol.app.Event, world_state: ?*anyopaque) void {
        if (world_state) |state| {
            const self: *WorldState = @alignCast(@ptrCast(state));
            _ = self;

            if (ev.*.key_code == .ESCAPE and ev.*.type == .KEY_DOWN) {
                sokol.app.requestQuit();
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const status = gpa.deinit();
        if (status == .leak) std.debug.print("memory leak detected!\n", .{});
    }

    var world = WorldState.init(allocator);
    defer world.deinit();

    world.run();
}
