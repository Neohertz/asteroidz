const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");

const StateObject = struct {
    elapsedTime: f32 = 0.0,
    deltaTime: f32 = 0.0,
};

var state = StateObject{};

fn update() void {}

fn render() void {}

pub fn main() anyerror!void {
    const SCREEN_WIDTH = 800;
    const SCREEN_HEIGHT = 450;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Raylib-Zig Game");
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        state.deltaTime = rl.getFrameTime();
        state.elapsedTime += state.deltaTime;

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        // [0:*] denotes that the array is null-terminated (unknown length).
        // https://discord.com/channels/605571803288698900/1333448529187967147/1333453897494302750
        const ref = try std.fmt.allocPrintZ(alloc, "Elapsed Time: {d:.2}", .{state.elapsedTime});
        defer alloc.free(ref);

        rl.drawText(
            ref,
            5,
            5,
            12,
            rl.Color.white,
        );
    }
}
