const std = @import("std");

// Simple PRNG for repeatable noise
fn hash(seed: u32, x: i32, y: i32) u32 {
    var h = seed +% @as(u32, @bitCast(x)) *% 1664525 +% @as(u32, @bitCast(y)) *% 1013904223;
    h ^= h >> 16;
    h *%= 0x85ebca6b;
    h ^= h >> 13;
    h *%= 0xc2b2ae35;
    h ^= h >> 16;
    return h;
}

// Smoothstep-like fade function (Perlin's 6t^5 - 15t^4 + 10t^3)
fn fade(t: f32) f32 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Linear interpolation
fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

// Generate a random gradient vector based on grid position
fn gradient(seed: u32, ix: i32, iy: i32) [2]f32 {
    const r = hash(seed, ix, iy);
    const angle = @as(f32, @floatFromInt(r)) / @as(f32, @floatFromInt(std.math.maxInt(u32))) * 2.0 * std.math.pi;
    return [2]f32{ @cos(angle), @sin(angle) };
}

// Dot product of distance vector and gradient
fn dotGradient(seed: u32, ix: i32, iy: i32, x: f32, y: f32) f32 {
    const grad = gradient(seed, ix, iy);
    const dx = x - @as(f32, @floatFromInt(ix));
    const dy = y - @as(f32, @floatFromInt(iy));
    return dx * grad[0] + dy * grad[1];
}

// 2D Perlin noise function
pub fn noise(seed: u32, x: f32, y: f32) f32 {
    const x0 = @as(i32, @intFromFloat(@floor(x)));
    const x1 = x0 + 1;
    const y0 = @as(i32, @intFromFloat(@floor(y)));
    const y1 = y0 + 1;

    // Fractional parts
    const fx = x - @as(f32, @floatFromInt(x0));
    const fy = y - @as(f32, @floatFromInt(y0));

    // Compute dot products for each corner
    const n00 = dotGradient(seed, x0, y0, x, y);
    const n10 = dotGradient(seed, x1, y0, x, y);
    const n01 = dotGradient(seed, x0, y1, x, y);
    const n11 = dotGradient(seed, x1, y1, x, y);

    // Interpolate along x
    const u = fade(fx);
    const nx0 = lerp(n00, n10, u);
    const nx1 = lerp(n01, n11, u);

    // Interpolate along y
    const v = fade(fy);
    return lerp(nx0, nx1, v);
}

pub fn generatePerlinNoiseImage() void {
    // Image dimensions
    const width: usize = 512;
    const height: usize = 512;

    // Noise parameters
    const seed: u32 = 42;
    const scale: f32 = 0.005; // Adjust this to change noise frequency
    const octaves: usize = 4; // Number of octaves for fractal noise

    // Create a file for the image
    const file = try std.fs.cwd().createFile("noise.ppm", .{});
    defer file.close();

    // Write PPM header
    try file.writer().print("P3\n{d} {d}\n255\n", .{ width, height });

    // Generate noise and write pixel data
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            // Generate fractal noise by summing multiple octaves
            var noise_value: f32 = 0.0;
            var amplitude: f32 = 1.0;
            var frequency: f32 = 1.0;
            var max_value: f32 = 0.0;

            var i: usize = 0;
            while (i < octaves) : (i += 1) {
                const sample_x = @as(f32, @floatFromInt(x)) * scale * frequency;
                const sample_y = @as(f32, @floatFromInt(y)) * scale * frequency;

                noise_value += noise(seed +% @as(u32, @intCast(i)), sample_x, sample_y) * amplitude;

                max_value += amplitude;
                amplitude *= 0.5;
                frequency *= 2.0;
            }

            // Normalize the noise to [0, 1]
            noise_value = (noise_value / max_value + 1.0) * 0.5;

            // Convert to 0-255 range for RGB values
            const color = @as(u8, @intFromFloat(noise_value * 255.0));

            // Write the RGB triplet
            try file.writer().print("{d} {d} {d}\n", .{ color, color, color });
        }
    }

    std.debug.print("Generated noise image: noise.ppm\n", .{});
}
