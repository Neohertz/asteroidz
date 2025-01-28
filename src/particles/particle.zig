// Custom Particle Emitter System.

const std = @import("std");
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const math = std.math;

pub const Particle = struct {
    position: Vector2,
    size: f32,
    color: rl.Color,
    lifespan: f32,
    direction: f32,
    shape: EmitterShape,
    aliveTime: f32 = 0.0,

    // Return a value from 0 to 1, where 0 is spawn, and 1 is death.
    pub fn percentage(self: *Particle) f32 {
        return math.clamp(self.aliveTime / self.lifespan, 0.0, 1.0);
    }

    pub fn draw(self: *Particle) void {
        switch (self.shape) {
            .SQUARE => rl.drawRectangleV(self.position, Vector2.one().scale(self.size), self.color),
            .CIRCLE => rl.drawCircleV(self.position, self.size, self.color),
        }
    }
};

fn BaseLerpable(comptime T: type) type {
    return struct { start: T, end: T };
}

pub const EmitterShape = enum {
    SQUARE,
    CIRCLE,
};

pub const EmitterConfig = struct {
    shape: EmitterShape = EmitterShape.CIRCLE,
    position: Vector2,
    rate: f32 = 0.1,
    velocity: f32 = 10,
    rotation: f32 = 0,
    sprayAngle: f32 = math.tau,
    color: ColorLerpable = ColorLerpable{ .start = rl.Color.white, .end = rl.Color.white },
    size: F32Lerpable = F32Lerpable{ .start = 5, .end = 3 },
    opacity: F32Lerpable = F32Lerpable{ .start = 0, .end = 0 },
    lifetime: f32 = 1,
};

pub const ColorLerpable = BaseLerpable(rl.Color);
pub const F32Lerpable = BaseLerpable(f32);

pub const Emitter = struct {
    alloc: std.mem.Allocator,
    particles: std.ArrayList(Particle) = undefined,
    rng: std.Random = undefined,

    config: EmitterConfig,
    aliveTime: f32 = 0.0,
    lastSpawn: f32 = 0.0,
    enabled: bool = true,

    __dead: bool = false,

    fn spawn(self: *Emitter) !void {
        if (!self.enabled) return;

        const rotMiddle = self.config.rotation;
        const half = (self.config.sprayAngle) / 2;
        const min = rotMiddle - half;
        const max = rotMiddle + half;
        const dist = max - min;
        var final = min + (self.rng.float(f32) * dist);
        final -= math.tau / 4.0;

        try self.particles.append(Particle{
            .position = self.config.position,
            .size = self.config.size.start,
            .lifespan = self.config.lifetime,
            .color = self.config.color.start,
            .direction = final,
            .shape = self.config.shape,
        });
    }

    pub fn step(self: *Emitter, delta: f32) !void {
        if (self.__dead) return;

        self.aliveTime += delta;

        if (self.aliveTime - self.lastSpawn > self.config.rate) {
            self.lastSpawn = self.aliveTime;
            try self.spawn();
        }

        // Step and check existing particles.
        for (self.particles.items, 0..) |*particle, i| {
            particle.aliveTime += delta;

            const percentage = particle.percentage();

            particle.size = math.lerp(self.config.size.start, self.config.size.end, percentage);

            particle.color = rl.colorAlpha(
                rl.colorLerp(self.config.color.start, self.config.color.end, percentage),
                1.0 - math.lerp(self.config.opacity.start, self.config.opacity.end, percentage),
            );

            const rotVector = Vector2.init(
                math.cos(particle.direction),
                math.sin(particle.direction),
            );

            particle.position = particle.position.add(rotVector.scale(self.config.velocity * delta));

            if (particle.aliveTime > particle.lifespan) {
                if (i < self.particles.items.len) {
                    _ = self.particles.orderedRemove(i);
                    continue;
                }
            }

            particle.draw();
        }
    }

    pub fn deinit(self: *Emitter) void {
        self.__dead = true;
        self.particles.deinit();
    }
};

pub fn CreateEmitter(alloc: std.mem.Allocator, random: std.Random, config: EmitterConfig) !Emitter {
    return Emitter{
        .particles = std.ArrayList(Particle).init(alloc),
        .alloc = alloc,
        .rng = random,
        .config = config,
    };
}
