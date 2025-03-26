// const std = @import("std");
// const pine = @import("pine");
// const sokol = @import("sokol");
//
// pub const std_options = std.Options{
//     .logFn = pine.logging.log_fn,
// };
//
// const Grid = struct {
//     const size: f32 = 40.0; // total size of the grid
//     const resolution: u32 = 16; // number of cells along each axis (nxn)
//
//     // derived values
//     const cells_per_side = resolution;
//     const vertices_per_side = resolution + 1;
//     const vertex_count = vertices_per_side * vertices_per_side;
//
//     // for filled triangles
//     const triangles_per_cell = 2;
//     const triangles_count = cells_per_side * cells_per_side * triangles_per_cell;
//     const indices_count_filled = triangles_count * 3;
//
//     // for wireframe - we draw lines for all horizontal and vertical grid lines
//     const h_lines_count = vertices_per_side * cells_per_side; // horizontal lines
//     const v_lines_count = cells_per_side * vertices_per_side; // vertical lines
//     const indices_count_wireframe = (h_lines_count + v_lines_count) * 2;
//
//     label: []const u8,
//     vertices: [vertex_count * 7]f32 = undefined, // x,y,z + r,g,b,a
//     indices_filled: [indices_count_filled]u32 = undefined,
//     indices_wireframe: [indices_count_wireframe]u32 = undefined,
//
//     pub fn init(label: []const u8) Grid {
//         var grid = Grid{
//             .label = label,
//         };
//
//         grid.generateVertices();
//         grid.generateIndices();
//
//         return grid;
//     }
//
//     fn generateVertices(self: *Grid) void {
//         var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())));
//         var rand = prng.random();
//
//         const cell_size = size / @as(f32, @floatFromInt(cells_per_side));
//         const half_size = size / 2.0;
//
//         var idx: u32 = 0;
//         var z: u32 = 0;
//         while (z < vertices_per_side) : (z += 1) {
//             var x: u32 = 0;
//             while (x < vertices_per_side) : (x += 1) {
//                 const pos_x = @as(f32, @floatFromInt(x)) * cell_size - half_size;
//                 const pos_z = @as(f32, @floatFromInt(z)) * cell_size - half_size;
//
//                 // generate more interesting height values using position
//                 const height_scale = 5.0;
//                 const height = (rand.float(f32) * 0.7) +
//                     (0.3 * @cos(pos_x * 0.2) * @sin(pos_z * 0.2)) * height_scale;
//                 // const height = 0;
//
//                 self.vertices[idx + 0] = pos_x;
//                 self.vertices[idx + 1] = height;
//                 self.vertices[idx + 2] = pos_z;
//
//                 // color based on height (green to white gradient)
//                 const normalized_height = height / height_scale;
//                 self.vertices[idx + 3] = 0.2 + normalized_height * 0.8; // r (more red at higher elevations)
//                 self.vertices[idx + 4] = 0.7; // g (always some green)
//                 self.vertices[idx + 5] = 0.2 + normalized_height * 0.8; // b (more blue at higher elevations)
//                 self.vertices[idx + 6] = 1.0; // a (always fully opaque)
//
//                 idx += 7;
//             }
//         }
//     }
//
//     fn generateIndices(self: *Grid) void {
//         // generate indices for filled triangles
//         var idx_filled: u32 = 0;
//
//         var z: u32 = 0;
//         while (z < cells_per_side) : (z += 1) {
//             var x: u32 = 0;
//             while (x < cells_per_side) : (x += 1) {
//                 // calculate indices for the corners of this grid cell
//                 const top_left = z * vertices_per_side + x;
//                 const top_right = top_left + 1;
//                 const bottom_left = (z + 1) * vertices_per_side + x;
//                 const bottom_right = bottom_left + 1;
//
//                 // first triangle (top-left, bottom-left, bottom-right)
//                 self.indices_filled[idx_filled + 0] = @intCast(top_left);
//                 self.indices_filled[idx_filled + 1] = @intCast(bottom_left);
//                 self.indices_filled[idx_filled + 2] = @intCast(bottom_right);
//
//                 // second triangle (top-left, bottom-right, top-right)
//                 self.indices_filled[idx_filled + 3] = @intCast(top_left);
//                 self.indices_filled[idx_filled + 4] = @intCast(bottom_right);
//                 self.indices_filled[idx_filled + 5] = @intCast(top_right);
//
//                 idx_filled += 6;
//             }
//         }
//
//         // generate indices for wireframe view
//         var idx_wireframe: u32 = 0;
//
//         // horizontal lines (z-constant lines along x-axis)
//         z = 0;
//         while (z < vertices_per_side) : (z += 1) {
//             var x: u32 = 0;
//             while (x < cells_per_side) : (x += 1) {
//                 const start_idx = z * vertices_per_side + x;
//                 const end_idx = start_idx + 1;
//
//                 self.indices_wireframe[idx_wireframe + 0] = @intCast(start_idx);
//                 self.indices_wireframe[idx_wireframe + 1] = @intCast(end_idx);
//
//                 idx_wireframe += 2;
//             }
//         }
//
//         // vertical lines (x-constant lines along z-axis)
//         var x: u32 = 0;
//         while (x < vertices_per_side) : (x += 1) {
//             z = 0;
//             while (z < cells_per_side) : (z += 1) {
//                 const start_idx = z * vertices_per_side + x;
//                 const end_idx = start_idx + vertices_per_side;
//
//                 self.indices_wireframe[idx_wireframe + 0] = @intCast(start_idx);
//                 self.indices_wireframe[idx_wireframe + 1] = @intCast(end_idx);
//
//                 idx_wireframe += 2;
//             }
//         }
//     }
// };
//
// const WorldState = struct {
//     allocator: std.mem.Allocator,
//     resource_manager: pine.ResourceManager,
//     camera: pine.Camera,
//     renderer: pine.Renderer,
//     grid: Grid,
//
//     pub fn init(allocator: std.mem.Allocator) WorldState {
//         const camera = pine.Camera.init(
//             pine.math.Vec3.with(40, 30, 40),
//             pine.math.Vec3.zeros(),
//             60,
//             4 / 3,
//             0.01,
//             100,
//         );
//
//         return .{
//             .allocator = allocator,
//             .resource_manager = pine.ResourceManager.init(allocator),
//             .camera = camera,
//             .renderer = pine.Renderer.init(allocator, camera),
//             .grid = Grid.init("grid-example"),
//         };
//     }
//
//     pub fn deinit(self: *WorldState) void {
//         self.resource_manager.deinit();
//         self.renderer.deinit();
//
//         // important
//         sokol.gfx.shutdown();
//     }
//
//     pub fn run(self: *WorldState) void {
//         sokol.app.run(sokol.app.Desc{
//             .init_userdata_cb = sokolInitTerrainExample,
//             .frame_userdata_cb = sokolFrameTerrainExample,
//             .event_userdata_cb = sokolEventTerrainExample,
//             .user_data = self,
//             .logger = .{ .func = sokol.log.func },
//             .icon = .{ .sokol_default = true },
//             .sample_count = 4,
//             .width = 4 * 300,
//             .height = 3 * 300,
//             .window_title = "Pine: Terrain Example",
//         });
//     }
//
//     export fn sokolInitTerrainExample(world_state: ?*anyopaque) void {
//         if (world_state) |state| {
//             const self: *WorldState = @alignCast(@ptrCast(state));
//
//             sokol.gfx.setup(.{
//                 .environment = sokol.glue.environment(),
//                 .logger = .{ .func = sokol.log.func },
//             });
//
//             self.resource_manager.createMesh(self.grid.label, &self.grid.vertices, &self.grid.indices_filled) catch |err| {
//                 std.log.err("failed to create terrain mesh: {}", .{err});
//                 @panic("FAILED TO CREATE TERRAIN MESH!\n");
//             };
//
//             self.resource_manager.createShader(
//                 self.grid.label,
//                 @embedFile("shaders/terrain.vs.metal"),
//                 @embedFile("shaders/terrain.fs.metal"),
//                 sokol.gfx.queryBackend(),
//             ) catch |err| {
//                 std.log.err("failed to create terrain shader: {}", .{err});
//                 @panic("FAILED TO CREATE TERRAIN SHADER!\n");
//             };
//
//             self.resource_manager.createTransform(
//                 self.grid.label,
//                 pine.math.Vec3.zeros(),
//                 .{},
//                 pine.math.Vec3.ones(),
//             ) catch |err| {
//                 std.log.err("failed to create terrain transform: {}", .{err});
//                 @panic("FAILED TO CREATE TERRAIN TRANSFORM!\n");
//             };
//
//             self.resource_manager.createMaterial(self.grid.label, self.grid.label) catch |err| {
//                 std.log.err("failed to create terrain material: {}", .{err});
//                 @panic("FAILED TO CREATE TERRAIN MATERIAL!\n");
//             };
//         }
//     }
//
//     export fn sokolFrameTerrainExample(world_state: ?*anyopaque) void {
//         if (world_state) |state| {
//             const self: *WorldState = @alignCast(@ptrCast(state));
//
//             const dt = sokol.app.frameDuration();
//
//             // apply rotation
//             const transform = if (self.resource_manager.getTransform(self.grid.label)) |transform| blk: {
//                 transform.rotate(pine.math.Vec3.up(), @floatCast(dt * 0.25));
//                 break :blk transform;
//             } else blk: {
//                 break :blk null;
//             };
//
//             self.renderer.addRenderCommand(.{
//                 .mesh = self.resource_manager.getMesh(self.grid.label),
//                 .transform = transform,
//                 .material = self.resource_manager.getMaterial(self.grid.label),
//             }) catch |err| {
//                 std.log.err("failed to add render command: {}", .{err});
//             };
//
//             self.renderer.render(&self.resource_manager);
//         }
//     }
//
//     export fn sokolEventTerrainExample(ev: [*c]const sokol.app.Event, world_state: ?*anyopaque) void {
//         if (world_state) |state| {
//             const self: *WorldState = @alignCast(@ptrCast(state));
//             _ = self;
//
//             if (ev.*.key_code == .ESCAPE and ev.*.type == .KEY_DOWN) {
//                 sokol.app.requestQuit();
//             }
//         }
//     }
// };
//
// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const allocator = gpa.allocator();
//     defer {
//         const status = gpa.deinit();
//         if (status == .leak) std.debug.print("memory leak detected!\n", .{});
//     }
//
//     var world = WorldState.init(allocator);
//     defer world.deinit();
//
//     world.run();
// }

pub fn main() !void {}
