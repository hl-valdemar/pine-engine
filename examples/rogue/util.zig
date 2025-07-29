const std = @import("std");

const pine = @import("pine-engine");

// dynamic lighting effect
pub fn calculateLighting(
    base_color: pine.terminal.ColorRGB,
    light_source: struct { x: i16, y: i16, intensity: f32, color: pine.terminal.ColorRGB },
    cell_pos: struct { x: i16, y: i16 },
) pine.terminal.ColorRGB {
    const dx = @as(f32, @floatFromInt(cell_pos.x - light_source.x));
    const dy = @as(f32, @floatFromInt(cell_pos.y - light_source.y));
    const distance = @sqrt(dx * dx + (dy * 2) * (dy * 2));

    // calculate falloff
    const falloff = std.math.clamp(1.0 - (distance / light_source.intensity), 0.0, 1.0);

    if (falloff <= 0.0) {
        return base_color;
    }

    // blend light color with base color
    const lit_color = pine.terminal.colors.blendRgb(base_color, light_source.color, falloff * 0.5);

    // apply brightness
    return pine.terminal.colors.lighten(lit_color, falloff * 0.3);
}
