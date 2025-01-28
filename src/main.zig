/// To learn more about zig, I decided to write a little asteroids clone with raylib. :)
/// Due for a massive refactor, but at least it's pretty fun to play!
///
/// REWRITE NOTES:
/// - Adopt native zig ecs (https://github.com/prime31/zig-ecs)
/// - Fix the clutter. Move redundant operations to public functions.
///
const std = @import("std");
const rl = @import("raylib");
const gui = @import("raygui");

const drawUtil = @import("./util/draw-util.zig");
const particle = @import("./particles/particle.zig");

const Vector2 = rl.Vector2;
const math = std.math;

// STRUCTS //////////////////////////////////////
const Projectile = struct {
    speed: f32,
    position: Vector2,
    direction: Vector2,
};

const Asteroid = struct {
    radius: f32,
    position: Vector2,
    direction: Vector2 = Vector2.init(0, 0),
    speed: f32,
    hp: i8 = 1,
};

const ShipObject = struct {
    position: Vector2,
    velocity: Vector2 = Vector2.init(0, 0),
    scale: f32 = 20,
    rotation: f32 = 0,
    lastShotAt: f32 = 0,
    flying: bool = false,
};

const StateObject = struct {
    projectiles: std.ArrayList(Projectile),
    asteroids: std.ArrayList(Asteroid),
    score: i64 = 0,
    deltaTime: f32 = 0.0,
    elapsedTime: f32 = 0.0,
    lastSpawn: f32 = -1000.0,
    spawnRate: f32 = 0.5,
    asteroidSpeed: f32 = 100,
    ship: ShipObject,
};

// ENUM //////////////////////////////////////
const AsteroidSize = enum { SMALL, MEDIUM, BIG };

// CONSTANTS //////////////////////////////////////
const CANVAS_SIZE = Vector2.init(1200, 800);
var alloc: std.mem.Allocator = undefined;
var rng: std.Random = undefined;
var rocketParticle: particle.Emitter = undefined;

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

fn inScreenBounds(origin: Vector2, bounds: Vector2) bool {
    const br = origin.add(bounds.scale(0.5));
    const tl = origin.subtract(bounds.scale(0.5));
    return (br.y > 0) and (tl.y < CANVAS_SIZE.y) or (br.x > 0) and (tl.y < CANVAS_SIZE.y);
}

fn fireProjectile(origin: Vector2, direction: Vector2) !void {
    try state.projectiles.append(.{
        .direction = direction,
        .position = origin,
        .speed = 350,
    });
}

fn createAsteroid(position: Vector2, radius: f32, speed: f32, direction: Vector2) !void {
    try state.asteroids.append(.{
        .position = position,
        .radius = radius,
        .speed = speed,
        .direction = direction,
    });
}

// FIX: this is kinda bad
fn resetGame() void {
    state.projectiles.clearAndFree();
    state.asteroids.clearAndFree();

    state = .{
        .asteroidSpeed = 100,
        .spawnRate = 0.5,
        .ship = .{
            .position = CANVAS_SIZE.scale(0.5),
        },
        .score = 0,
        .projectiles = state.projectiles,
        .asteroids = state.asteroids,
        .elapsedTime = 0,
    };
}

// LIFECYCLE //////////////////////////////////////
fn render() !void {
    // Rotations per second.
    const ROT_SPEED = 1;
    const SHIP_DRAG = 0.03;
    // Pixels per second.
    const SHIP_SPEED = 10;
    // Per Second
    const FIRE_RATE = 2;

    // Rotate the Ship
    if (rl.isKeyDown(.d)) {
        state.ship.rotation += state.deltaTime * math.tau * ROT_SPEED;
    }

    if (rl.isKeyDown(.a)) {
        state.ship.rotation -= state.deltaTime * math.tau * ROT_SPEED;
    }

    // Rotate the angle by 90 degrees.
    const fixedAngle = state.ship.rotation + (math.tau / 4.0);
    const shipDir = Vector2.init(
        math.cos(fixedAngle),
        math.sin(fixedAngle),
    );

    // Move ship (velocity)
    if (rl.isKeyDown(.w)) {
        state.ship.flying = true;
        state.ship.velocity = state.ship.velocity.add(
            shipDir.scale(SHIP_SPEED * state.deltaTime),
        );
    } else {
        state.ship.flying = false;
    }

    state.ship.velocity = state.ship.velocity.scale(1.0 - SHIP_DRAG);
    state.ship.position = wrapPosition(state.ship.position.add(state.ship.velocity));

    // Particles
    rocketParticle.config.rotation = state.ship.rotation;
    rocketParticle.config.position = state.ship.position.subtract(shipDir.scale(12));
    rocketParticle.enabled = state.ship.flying;
    try rocketParticle.step(state.deltaTime);

    // Projectiles
    if (rl.isKeyPressed(.space)) {
        if (state.elapsedTime - state.ship.lastShotAt > (1 / FIRE_RATE)) {
            state.ship.lastShotAt = state.elapsedTime;
            try fireProjectile(state.ship.position.add(shipDir), shipDir);
        }
    }

    // Step Projectiles
    for (state.projectiles.items, 0..) |*projectile, i| {
        projectile.position = projectile.position.add(
            projectile.direction.scale(projectile.speed * state.deltaTime),
        );

        // Check if the projectile is on screen. If not, attempt to remove it.
        if (!inScreenBounds(projectile.position, Vector2.one())) {
            // Prevent null access.
            if (!(i > state.projectiles.items.len - 1)) {
                _ = state.projectiles.orderedRemove(i);
            }
        }

        rl.drawCircleV(projectile.position, 1.0, rl.Color.white);
    }

    // Asteroids
    for (state.asteroids.items, 0..) |*asteroid, i| {
        asteroid.position = asteroid.position.add(
            asteroid.direction.scale(asteroid.speed * state.deltaTime),
        );

        // Check if the projectile is on screen. If not, attempt to remove it.
        if (!inScreenBounds(asteroid.position, Vector2.one().scale(asteroid.radius))) {
            // Prevent null access.
            if (i < state.asteroids.items.len) {
                _ = state.asteroids.orderedRemove(i);
            }
        }

        const asteroidBB = rl.Rectangle.init(
            asteroid.position.x - asteroid.radius,
            asteroid.position.y - asteroid.radius,
            asteroid.radius * 2,
            asteroid.radius * 2,
        );

        const playerBB = rl.Rectangle.init(
            state.ship.position.x - (state.ship.scale / 2),
            state.ship.position.y,
            state.ship.scale,
            state.ship.scale,
        );

        if (asteroidBB.checkCollision(playerBB)) {
            resetGame();
            return;
        }

        // collision
        for (state.projectiles.items) |*projectile| {
            const projectileBB = rl.Rectangle.init(projectile.position.x, projectile.position.y, 2.0, 2.0);
            if (projectileBB.checkCollision(asteroidBB)) {
                if (i < state.asteroids.items.len) {
                    _ = state.asteroids.orderedRemove(i);
                    state.score += 1;
                }
            }

            //rl.checkCollisionRecs(rec1: Rectangle, rec2: Rectangle)
        }

        rl.drawCircleLinesV(asteroid.position, asteroid.radius, rl.Color.red);
    }

    // Draw the ship
    drawUtil.drawLines(
        state.ship.position,
        1,
        state.ship.scale,
        state.ship.rotation,
        &.{
            Vector2.init(-0.4, -0.5),
            Vector2.init(0.0, 0.5),
            Vector2.init(0.4, -0.5),
            Vector2.init(-0.4, -0.5),
        },
        rl.Color.blue,
    );

    // [0:*] denotes that the array is null-terminated (unknown length).
    // https://discord.com/channels/605571803288698900/1333448529187967147/1333453897494302750
    const ref = try std.fmt.allocPrintZ(alloc, "Score: {any} | FPS: {any} | Time Alive: {d:.2} | Frame Time: {d:.2} ", .{
        state.score,
        rl.getFPS(),
        state.elapsedTime,
        state.deltaTime,
    });
    defer alloc.free(ref);

    rl.drawText(
        ref,
        5,
        5,
        20,
        rl.Color.white,
    );
}

pub fn main() !void {
    // 1 Every X seconds.

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    alloc = gpa.allocator();

    // Random number generato (Xoshiro256)
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    rng = prng.random();

    rocketParticle = try particle.CreateEmitter(alloc, rng, .{
        .shape = .CIRCLE,
        .rate = 0.0,
        .lifetime = 1,
        .position = Vector2.init(CANVAS_SIZE.x / 2.0, CANVAS_SIZE.y / 2.0),
        .velocity = 300,
        .sprayAngle = 90 * math.rad_per_deg,
        .rotation = 0,
        .opacity = .{ .start = 0.3, .end = 1.0 },
        .size = .{ .start = 5.0, .end = 0 },
        .color = .{ .start = rl.Color.red, .end = rl.Color.orange },
    });
    defer rocketParticle.deinit();

    rl.initWindow(CANVAS_SIZE.x, CANVAS_SIZE.y, "Zig Game");
    defer rl.closeWindow();
    rl.setTargetFPS(120);

    // Initialize our state
    state = .{
        .ship = .{
            .position = CANVAS_SIZE.scale(0.5),
        },
        .projectiles = std.ArrayList(Projectile).init(alloc),
        .asteroids = std.ArrayList(Asteroid).init(alloc),
    };

    defer state.projectiles.deinit();
    defer state.asteroids.deinit();

    const color = try alloc.alloc(rl.Color, 1);
    defer alloc.free(color);

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        state.deltaTime = rl.getFrameTime();
        state.elapsedTime += state.deltaTime;

        state.spawnRate -= state.deltaTime / 1000;
        state.asteroidSpeed += state.deltaTime * 10;

        if (state.elapsedTime - state.lastSpawn > state.spawnRate) {
            state.lastSpawn = state.elapsedTime;
            const xEdge = @as(f32, @floatFromInt(rng.intRangeAtMost(i8, 0, 1))) * CANVAS_SIZE.x;
            const yEdge = @as(f32, @floatFromInt(rng.intRangeAtMost(i8, 0, 1))) * CANVAS_SIZE.y;

            const goal = Vector2.init(
                @as(f32, @floatFromInt(rng.intRangeAtMost(i32, CANVAS_SIZE.x * 0.25, CANVAS_SIZE.x * 0.75))),
                @as(f32, @floatFromInt(rng.intRangeAtMost(i32, CANVAS_SIZE.y * 0.25, CANVAS_SIZE.y * 0.75))),
            );

            const origin = Vector2.init(xEdge, yEdge);

            try createAsteroid(
                origin,
                rng.float(f32) * 10 + 10,
                state.asteroidSpeed,
                goal.subtract(origin).normalize(),
            );
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        try render();
        // _ = gui.guiColorPicker(.{ .height = 100.0, .width = 200.0, .x = 100.0, .y = 100.0 }, "This is a test!", &color[0]);
    }
}
