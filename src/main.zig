const std = @import("std");
const rl = @import("raylib");
const drawUtil = @import("./util/draw-util.zig");

const Vector2 = rl.Vector2;
const math = std.math;

// STRUCTS //////////////////////////////////////
const ShipObject = struct {
    position: Vector2,
    velocity: Vector2 = Vector2.init(0, 0),
    scale: f32 = 1,
    rotation: f32 = 0,
};

const StateObject = struct {
    elapsedTime: f32 = 0.0,
    deltaTime: f32 = 0.0,
    ship: ShipObject,
};

// CONSTANTS //////////////////////////////////////
const CANVAS_SIZE = Vector2.init(640, 480);
var alloc: std.mem.Allocator = undefined;

// STATE //////////////////////////////////////
var state: StateObject = undefined;

// HELPERS //////////////////////////////////////

// Wrap the position so that it's always within the viewport.
fn wrapPosition(vec: Vector2) Vector2 {
    return Vector2.init(
        @mod(vec.x, CANVAS_SIZE.x),
        @mod(vec.y, CANVAS_SIZE.y),
    );
}

// LIFECYCLE //////////////////////////////////////
fn render() !void {
    // Rotations per second.
    const ROT_SPEED = 1;
    const SHIP_DRAG = 0.03;
    // Pixels per second.
    const SHIP_SPEED = 10;

    // Rotate the Ship
    if (rl.isKeyDown(.d)) {
        state.ship.rotation += state.deltaTime * math.tau * ROT_SPEED;
    }

    if (rl.isKeyDown(.a)) {
        state.ship.rotation -= state.deltaTime * math.tau * ROT_SPEED;
    }

    const fixedAngle = state.ship.rotation + (math.tau / 4.0);
    const shipDir = Vector2.init(
        math.cos(fixedAngle),
        math.sin(fixedAngle),
    );

    // Move ship (velocity)
    if (rl.isKeyDown(.w)) {
        state.ship.velocity = state.ship.velocity.add(
            shipDir.scale(SHIP_SPEED * state.deltaTime),
        );
    }

    state.ship.velocity = state.ship.velocity.scale(1.0 - SHIP_DRAG);
    state.ship.position = wrapPosition(state.ship.position.add(state.ship.velocity));

    // Draw the ship
    drawUtil.drawLines(
        state.ship.position,
        1,
        15,
        state.ship.rotation,
        &.{
            Vector2.init(-0.4, -0.5),
            Vector2.init(0.0, 0.5),
            Vector2.init(0.4, -0.5),
            Vector2.init(-0.4, -0.5),
        },
        rl.Color.red,
    );

    // [0:*] denotes that the array is null-terminated (unknown length).
    // https://discord.com/channels/605571803288698900/1333448529187967147/1333453897494302750
    const ref = try std.fmt.allocPrintZ(alloc, "Frame Time: {d:.2}", .{state.deltaTime});
    defer alloc.free(ref);

    rl.drawText(
        ref,
        5,
        5,
        12,
        rl.Color.white,
    );
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    alloc = gpa.allocator();

    rl.initWindow(CANVAS_SIZE.x, CANVAS_SIZE.y, "Raylib-Zig Game");
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Initialize our space ship.
    state = .{
        .ship = .{
            .position = CANVAS_SIZE.scale(0.5),
        },
    };

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        state.deltaTime = rl.getFrameTime();
        state.elapsedTime += state.deltaTime;

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        try render();
    }
}
