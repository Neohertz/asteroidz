const rl = @import("raylib");
const Vector2 = rl.Vector2;

// Draw a list of lines, connecting each point to the point after it.
pub fn drawLines(origin: Vector2, thickness: f32, scale: f32, rotation: f32, points: []const Vector2, color: rl.Color) void {
    const Transformer = struct {
        origin: Vector2,
        scale: f32,
        rotation: f32,

        fn apply(self: @This(), p: Vector2) Vector2 {
            return p.rotate(self.rotation).scale(self.scale).add(self.origin);
        }
    };

    const t = Transformer{
        .origin = origin,
        .rotation = rotation,
        .scale = scale,
    };

    for (0..points.len) |i| {
        rl.drawLineEx(
            t.apply(points[i]),
            t.apply(points[(i + 1) % points.len]),
            thickness,
            color,
        );
    }
}
