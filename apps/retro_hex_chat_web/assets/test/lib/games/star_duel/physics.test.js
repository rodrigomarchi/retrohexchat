import { describe, it, expect } from "vitest";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/star_duel/protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  ROTATION_SPEED,
  THRUST_ACCEL,
  MAX_SPEED,
  DRAG,
  MISSILE_SPEED,
  MISSILE_LIFETIME,
  MISSILE_COOLDOWN,
  SHIP_RADIUS,
  SPAWN_INVULN,
  STAR_DANGER_RADIUS,
  STAR_X,
  STAR_Y,
  WARP_COOLDOWN,
  WARP_INVULN,
  ASTEROID_COUNT,
  ASTEROID_MIN_RADIUS,
  ASTEROID_MAX_RADIUS,
  createInitialState,
  updateShipRotation,
  applyThrust,
  applyDrag,
  capSpeed,
  updateShipPosition,
  fireMissile,
  updateMissiles,
  tickCooldowns,
  checkMissileShipCollision,
  checkShipShipCollision,
  attemptWarp,
  spawnShips,
  applyGravity,
  applyGravityToMissile,
  checkStarCollision,
  generateAsteroids,
  checkAsteroidShipCollision,
  checkAsteroidMissileCollision,
  createExplosionParticles,
  updateParticles,
} from "../../../../js/lib/games/star_duel/physics.js";

describe("star_duel_physics", () => {
  describe("createInitialState", () => {
    it("creates ship1 at (160, 240) with zero velocity", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.ship1.x).toBe(160);
      expect(state.ship1.y).toBe(240);
      expect(state.ship1.vx).toBe(0);
      expect(state.ship1.vy).toBe(0);
    });

    it("creates ship2 at (480, 240) with zero velocity", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.ship2.x).toBe(480);
      expect(state.ship2.y).toBe(240);
      expect(state.ship2.vx).toBe(0);
      expect(state.ship2.vy).toBe(0);
    });

    it("ship1 rotation is 0, ship2 rotation is PI", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.ship1.rotation).toBe(0);
      expect(state.ship2.rotation).toBe(Math.PI);
    });

    it("both ships are invulnerable and alive", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.ship1.invulnerable).toBe(true);
      expect(state.ship1.alive).toBe(true);
      expect(state.ship2.invulnerable).toBe(true);
      expect(state.ship2.alive).toBe(true);
    });

    it("starts with no missiles", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.missiles).toHaveLength(0);
    });

    it("preserves mode", () => {
      const state = createInitialState(GAME_MODE.GRAVITY_WELL);
      expect(state.mode).toBe(GAME_MODE.GRAVITY_WELL);
    });

    it("starts in WAITING phase", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.phase).toBe(PHASE.WAITING);
    });

    it("starts with zero scores", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.score1).toBe(0);
      expect(state.score2).toBe(0);
    });

    it("DEBRIS_FIELD mode has asteroids", () => {
      const state = createInitialState(GAME_MODE.DEBRIS_FIELD);
      expect(state.asteroids.length).toBeGreaterThan(0);
    });

    it("OPEN_SPACE mode has no asteroids", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      expect(state.asteroids).toHaveLength(0);
    });

    it("GRAVITY_WELL mode has no asteroids", () => {
      const state = createInitialState(GAME_MODE.GRAVITY_WELL);
      expect(state.asteroids).toHaveLength(0);
    });

    it("explicit seed produces deterministic state", () => {
      const s1 = createInitialState(GAME_MODE.DEBRIS_FIELD, 12345);
      const s2 = createInitialState(GAME_MODE.DEBRIS_FIELD, 12345);
      expect(s1.asteroidSeed).toBe(12345);
      expect(s2.asteroidSeed).toBe(12345);
      expect(s1.asteroids.length).toBe(s2.asteroids.length);
      for (let i = 0; i < s1.asteroids.length; i++) {
        expect(s1.asteroids[i].x).toBe(s2.asteroids[i].x);
        expect(s1.asteroids[i].y).toBe(s2.asteroids[i].y);
        expect(s1.asteroids[i].radius).toBe(s2.asteroids[i].radius);
      }
    });

    it("different seeds produce different asteroid layouts", () => {
      const s1 = createInitialState(GAME_MODE.DEBRIS_FIELD, 100);
      const s2 = createInitialState(GAME_MODE.DEBRIS_FIELD, 200);
      const same = s1.asteroids.every(
        (a, i) => a.x === s2.asteroids[i].x && a.y === s2.asteroids[i].y,
      );
      expect(same).toBe(false);
    });
  });

  describe("updateShipRotation", () => {
    it("rotates right increases rotation", () => {
      const ship = { rotation: 0 };
      const result = updateShipRotation(ship, false, true);
      expect(result.rotation).toBeCloseTo(ROTATION_SPEED);
    });

    it("rotates left decreases rotation", () => {
      const ship = { rotation: 1.0 };
      const result = updateShipRotation(ship, true, false);
      expect(result.rotation).toBeCloseTo(1.0 - ROTATION_SPEED);
    });

    it("wraps from small angle left to stay positive (near 2*PI)", () => {
      const ship = { rotation: 0.01 };
      const result = updateShipRotation(ship, true, false);
      expect(result.rotation).toBeGreaterThan(0);
      expect(result.rotation).toBeLessThan(Math.PI * 2);
    });

    it("no rotation when neither pressed", () => {
      const ship = { rotation: 1.5 };
      const result = updateShipRotation(ship, false, false);
      expect(result.rotation).toBeCloseTo(1.5);
    });
  });

  describe("applyThrust", () => {
    it("applies acceleration in rotation=0 direction (vx increases)", () => {
      const ship = { vx: 0, vy: 0, rotation: 0, thrustActive: true };
      const result = applyThrust(ship);
      expect(result.vx).toBeCloseTo(THRUST_ACCEL);
      expect(result.vy).toBeCloseTo(0);
    });

    it("applies in rotation=PI/2 direction (vy increases)", () => {
      const ship = { vx: 0, vy: 0, rotation: Math.PI / 2, thrustActive: true };
      const result = applyThrust(ship);
      expect(result.vx).toBeCloseTo(0);
      expect(result.vy).toBeCloseTo(THRUST_ACCEL);
    });

    it("no effect when thrustActive is false", () => {
      const ship = { vx: 0, vy: 0, rotation: 0, thrustActive: false };
      const result = applyThrust(ship);
      expect(result.vx).toBe(0);
      expect(result.vy).toBe(0);
    });
  });

  describe("applyDrag", () => {
    it("reduces velocity", () => {
      const ship = { vx: 5, vy: 3 };
      const result = applyDrag(ship);
      expect(result.vx).toBeCloseTo(5 * DRAG);
      expect(result.vy).toBeCloseTo(3 * DRAG);
      expect(Math.abs(result.vx)).toBeLessThan(5);
      expect(Math.abs(result.vy)).toBeLessThan(3);
    });
  });

  describe("capSpeed", () => {
    it("does not change speed under MAX_SPEED", () => {
      const ship = { vx: 2, vy: 1 };
      const result = capSpeed(ship);
      expect(result.vx).toBe(2);
      expect(result.vy).toBe(1);
    });

    it("clamps speed at MAX_SPEED", () => {
      const ship = { vx: 10, vy: 10 };
      const result = capSpeed(ship);
      const speed = Math.sqrt(result.vx ** 2 + result.vy ** 2);
      expect(speed).toBeCloseTo(MAX_SPEED);
    });

    it("at exactly MAX_SPEED — unchanged", () => {
      // Ship moving at exactly MAX_SPEED along x-axis
      const ship = { vx: MAX_SPEED, vy: 0 };
      const result = capSpeed(ship);
      expect(result.vx).toBe(MAX_SPEED);
      expect(result.vy).toBe(0);
    });

    it("at zero velocity — unchanged", () => {
      const ship = { vx: 0, vy: 0 };
      const result = capSpeed(ship);
      expect(result.vx).toBe(0);
      expect(result.vy).toBe(0);
    });

    it("at exactly MAX_SPEED diagonal — unchanged", () => {
      // Construct a diagonal velocity vector with magnitude exactly MAX_SPEED
      const component = MAX_SPEED / Math.sqrt(2);
      const ship = { vx: component, vy: component };
      const result = capSpeed(ship);
      const speed = Math.sqrt(result.vx ** 2 + result.vy ** 2);
      expect(speed).toBeCloseTo(MAX_SPEED);
      // Should be returned unchanged (speed <= MAX_SPEED)
      expect(result.vx).toBeCloseTo(component);
      expect(result.vy).toBeCloseTo(component);
    });
  });

  describe("updateShipPosition", () => {
    it("moves ship by velocity", () => {
      const ship = { x: 100, y: 200, vx: 3, vy: -2 };
      const result = updateShipPosition(ship);
      expect(result.x).toBe(103);
      expect(result.y).toBe(198);
    });

    it("wraps past right edge", () => {
      const ship = { x: CANVAS_W - 1, y: 100, vx: 5, vy: 0 };
      const result = updateShipPosition(ship);
      expect(result.x).toBeLessThan(CANVAS_W);
      expect(result.x).toBeCloseTo(4);
    });

    it("wraps past left edge", () => {
      const ship = { x: 1, y: 100, vx: -5, vy: 0 };
      const result = updateShipPosition(ship);
      expect(result.x).toBeGreaterThan(0);
      expect(result.x).toBeCloseTo(CANVAS_W - 4);
    });

    it("wraps past bottom edge", () => {
      const ship = { x: 100, y: CANVAS_H - 1, vx: 0, vy: 5 };
      const result = updateShipPosition(ship);
      expect(result.y).toBeLessThan(CANVAS_H);
      expect(result.y).toBeCloseTo(4);
    });

    it("wraps past top edge", () => {
      const ship = { x: 100, y: 1, vx: 0, vy: -5 };
      const result = updateShipPosition(ship);
      expect(result.y).toBeGreaterThan(0);
      expect(result.y).toBeCloseTo(CANVAS_H - 4);
    });

    it("wrap with very large positive value (> 2*max)", () => {
      const ship = { x: 0, y: 0, vx: CANVAS_W * 2 + 50, vy: CANVAS_H * 3 + 100 };
      const result = updateShipPosition(ship);
      expect(result.x).toBeGreaterThanOrEqual(0);
      expect(result.x).toBeLessThan(CANVAS_W);
      expect(result.x).toBeCloseTo(50);
      expect(result.y).toBeGreaterThanOrEqual(0);
      expect(result.y).toBeLessThan(CANVAS_H);
      expect(result.y).toBeCloseTo(100);
    });

    it("wrap with very large negative value (< -max)", () => {
      const ship = { x: 0, y: 0, vx: -(CANVAS_W * 2 + 10), vy: -(CANVAS_H + 20) };
      const result = updateShipPosition(ship);
      expect(result.x).toBeGreaterThanOrEqual(0);
      expect(result.x).toBeLessThan(CANVAS_W);
      expect(result.x).toBeCloseTo(CANVAS_W - 10);
      expect(result.y).toBeGreaterThanOrEqual(0);
      expect(result.y).toBeLessThan(CANVAS_H);
      expect(result.y).toBeCloseTo(CANVAS_H - 20);
    });
  });

  describe("fireMissile", () => {
    it("creates missile when cooldown is 0", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 0 };
      const result = fireMissile(ship, 1, []);
      expect(result).not.toBeNull();
      expect(result.missile).toBeDefined();
      expect(result.missile.owner).toBe(1);
    });

    it("returns null when cooldown > 0", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 5 };
      const result = fireMissile(ship, 1, []);
      expect(result).toBeNull();
    });

    it("returns null when at MAX_MISSILES (3 per player)", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 0 };
      const missiles = [
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
      ];
      const result = fireMissile(ship, 1, missiles);
      expect(result).toBeNull();
    });

    it("resets cooldown on fire", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 0 };
      const result = fireMissile(ship, 1, []);
      expect(result.ship.fireCooldown).toBe(MISSILE_COOLDOWN);
    });

    it("missile starts at ship position offset by SHIP_RADIUS in rotation direction", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 0 };
      const result = fireMissile(ship, 1, []);
      expect(result.missile.x).toBeCloseTo(100 + SHIP_RADIUS);
      expect(result.missile.y).toBeCloseTo(200);
    });

    it("missile velocity includes ship velocity", () => {
      const ship = { x: 100, y: 200, vx: 3, vy: 2, rotation: 0, fireCooldown: 0 };
      const result = fireMissile(ship, 1, []);
      expect(result.missile.vx).toBeCloseTo(MISSILE_SPEED + 3);
      expect(result.missile.vy).toBeCloseTo(2);
    });

    it("counts only own missiles, not enemy missiles", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 0 };
      // 3 enemy missiles (owner=2) and 2 own missiles (owner=1) — should be able to fire
      const missiles = [
        { owner: 2, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 2, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 2, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
      ];
      const result = fireMissile(ship, 1, missiles);
      expect(result).not.toBeNull();
      expect(result.missile.owner).toBe(1);
    });

    it("returns null when own missiles are at limit even with enemy missiles present", () => {
      const ship = { x: 100, y: 200, vx: 0, vy: 0, rotation: 0, fireCooldown: 0 };
      const missiles = [
        { owner: 2, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
        { owner: 1, x: 0, y: 0, vx: 0, vy: 0, age: 0 },
      ];
      const result = fireMissile(ship, 1, missiles);
      expect(result).toBeNull();
    });
  });

  describe("updateMissiles", () => {
    it("moves missiles by velocity", () => {
      const missiles = [{ x: 100, y: 200, vx: 5, vy: -3, age: 0, owner: 1 }];
      const result = updateMissiles(missiles);
      expect(result[0].x).toBeCloseTo(105);
      expect(result[0].y).toBeCloseTo(197);
    });

    it("ages missiles", () => {
      const missiles = [{ x: 100, y: 200, vx: 0, vy: 0, age: 0, owner: 1 }];
      const result = updateMissiles(missiles);
      expect(result[0].age).toBe(1);
    });

    it("removes expired missiles (age >= MISSILE_LIFETIME)", () => {
      const missiles = [{ x: 100, y: 200, vx: 0, vy: 0, age: MISSILE_LIFETIME - 1, owner: 1 }];
      const result = updateMissiles(missiles);
      expect(result).toHaveLength(0);
    });

    it("wraps missiles past canvas edge", () => {
      const missiles = [{ x: CANVAS_W - 1, y: 100, vx: 5, vy: 0, age: 0, owner: 1 }];
      const result = updateMissiles(missiles);
      expect(result[0].x).toBeLessThan(CANVAS_W);
    });
  });

  describe("tickCooldowns", () => {
    it("decrements all cooldowns", () => {
      const ship = {
        fireCooldown: 5,
        warpCooldown: 10,
        invulnTimer: 20,
        invulnerable: true,
      };
      const result = tickCooldowns(ship);
      expect(result.fireCooldown).toBe(4);
      expect(result.warpCooldown).toBe(9);
      expect(result.invulnTimer).toBe(19);
    });

    it("does not go below zero", () => {
      const ship = {
        fireCooldown: 0,
        warpCooldown: 0,
        invulnTimer: 0,
        invulnerable: false,
      };
      const result = tickCooldowns(ship);
      expect(result.fireCooldown).toBe(0);
      expect(result.warpCooldown).toBe(0);
      expect(result.invulnTimer).toBe(0);
    });

    it("sets invulnerable=false when timer reaches 0", () => {
      const ship = {
        fireCooldown: 0,
        warpCooldown: 0,
        invulnTimer: 1,
        invulnerable: true,
      };
      const result = tickCooldowns(ship);
      expect(result.invulnTimer).toBe(0);
      expect(result.invulnerable).toBe(false);
    });

    it("keeps invulnerable=true when timer still positive", () => {
      const ship = {
        fireCooldown: 0,
        warpCooldown: 0,
        invulnTimer: 5,
        invulnerable: true,
      };
      const result = tickCooldowns(ship);
      expect(result.invulnerable).toBe(true);
    });
  });

  describe("checkMissileShipCollision", () => {
    it("detects hit from enemy missile", () => {
      const ship = { x: 100, y: 200, alive: true, invulnerable: false };
      const missiles = [{ x: 100, y: 200, vx: 0, vy: 0, owner: 2, age: 0 }];
      const result = checkMissileShipCollision(missiles, ship, 1);
      expect(result.hit).toBe(true);
    });

    it("ignores own missiles", () => {
      const ship = { x: 100, y: 200, alive: true, invulnerable: false };
      const missiles = [{ x: 100, y: 200, vx: 0, vy: 0, owner: 1, age: 0 }];
      const result = checkMissileShipCollision(missiles, ship, 1);
      expect(result.hit).toBe(false);
      expect(result.missiles).toHaveLength(1);
    });

    it("ignores invulnerable ships", () => {
      const ship = { x: 100, y: 200, alive: true, invulnerable: true };
      const missiles = [{ x: 100, y: 200, vx: 0, vy: 0, owner: 2, age: 0 }];
      const result = checkMissileShipCollision(missiles, ship, 1);
      expect(result.hit).toBe(false);
      expect(result.missiles).toHaveLength(1);
    });

    it("removes the hitting missile", () => {
      const ship = { x: 100, y: 200, alive: true, invulnerable: false };
      const missiles = [
        { x: 100, y: 200, vx: 0, vy: 0, owner: 2, age: 0 },
        { x: 500, y: 500, vx: 0, vy: 0, owner: 2, age: 0 },
      ];
      const result = checkMissileShipCollision(missiles, ship, 1);
      expect(result.hit).toBe(true);
      expect(result.missiles).toHaveLength(1);
      expect(result.missiles[0].x).toBe(500);
    });

    it("no hit when missile is far away", () => {
      const ship = { x: 100, y: 200, alive: true, invulnerable: false };
      const missiles = [{ x: 400, y: 400, vx: 0, vy: 0, owner: 2, age: 0 }];
      const result = checkMissileShipCollision(missiles, ship, 1);
      expect(result.hit).toBe(false);
      expect(result.missiles).toHaveLength(1);
    });

    it("no hit when ship is dead", () => {
      const ship = { x: 100, y: 200, alive: false, invulnerable: false };
      const missiles = [{ x: 100, y: 200, vx: 0, vy: 0, owner: 2, age: 0 }];
      const result = checkMissileShipCollision(missiles, ship, 1);
      expect(result.hit).toBe(false);
      expect(result.missiles).toHaveLength(1);
    });
  });

  describe("checkShipShipCollision", () => {
    it("detects collision when ships are close", () => {
      const ship1 = { x: 100, y: 200, alive: true, invulnerable: false };
      const ship2 = { x: 100 + SHIP_RADIUS, y: 200, alive: true, invulnerable: false };
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(true);
    });

    it("no collision when ships are far apart", () => {
      const ship1 = { x: 100, y: 200, alive: true, invulnerable: false };
      const ship2 = { x: 400, y: 200, alive: true, invulnerable: false };
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(false);
    });

    it("no collision when one ship is invulnerable", () => {
      const ship1 = { x: 100, y: 200, alive: true, invulnerable: true };
      const ship2 = { x: 100, y: 200, alive: true, invulnerable: false };
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(false);
    });

    it("no collision when one ship is dead", () => {
      const ship1 = { x: 100, y: 200, alive: false, invulnerable: false };
      const ship2 = { x: 100, y: 200, alive: true, invulnerable: false };
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(false);
    });

    it("at exactly 2*SHIP_RADIUS distance — no collision (uses <)", () => {
      // Place ships exactly 2*SHIP_RADIUS apart
      const ship1 = { x: 100, y: 200, alive: true, invulnerable: false };
      const ship2 = { x: 100 + SHIP_RADIUS * 2, y: 200, alive: true, invulnerable: false };
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(false);
    });

    it("just inside 2*SHIP_RADIUS — collision", () => {
      const ship1 = { x: 100, y: 200, alive: true, invulnerable: false };
      const ship2 = { x: 100 + SHIP_RADIUS * 2 - 0.01, y: 200, alive: true, invulnerable: false };
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(true);
    });
  });

  describe("attemptWarp", () => {
    it("returns null when cooldown > 0", () => {
      const ship = { alive: true, exploding: false, warpCooldown: 10 };
      const result = attemptWarp(ship, Math.random);
      expect(result).toBeNull();
    });

    it("returns null when ship is dead", () => {
      const ship = { alive: false, exploding: false, warpCooldown: 0 };
      const result = attemptWarp(ship, () => 0.5);
      expect(result).toBeNull();
    });

    it("returns null when ship is exploding", () => {
      const ship = { alive: true, exploding: true, warpCooldown: 0 };
      const result = attemptWarp(ship, () => 0.5);
      expect(result).toBeNull();
    });

    it("sets new position, cooldown, and invulnerability on survive", () => {
      const ship = {
        x: 100,
        y: 200,
        warpCooldown: 0,
        alive: true,
        exploding: false,
        invulnerable: false,
        invulnTimer: 0,
      };
      let callCount = 0;
      const fakeFn = () => {
        callCount++;
        if (callCount === 1) return 0.5; // death check (>= 0.2 means survive)
        if (callCount === 2) return 0.5; // x position
        return 0.3; // y position
      };
      const result = attemptWarp(ship, fakeFn);
      expect(result).not.toBeNull();
      expect(result.ship.warpCooldown).toBe(WARP_COOLDOWN);
      expect(result.ship.invulnerable).toBe(true);
      expect(result.ship.invulnTimer).toBe(WARP_INVULN);
      expect(result.ship.warping).toBe(true);
      expect(result.died).toBe(false);
      expect(result.ship.alive).toBe(true);
      expect(result.ship.exploding).toBe(false);
    });

    it("death when randomFn returns < WARP_DEATH_CHANCE", () => {
      const ship = {
        x: 100,
        y: 200,
        warpCooldown: 0,
        alive: true,
        exploding: false,
        invulnerable: false,
        invulnTimer: 0,
      };
      let callCount = 0;
      const fakeFn = () => {
        callCount++;
        if (callCount === 1) return 0.1; // < 0.2 => death
        return 0.5;
      };
      const result = attemptWarp(ship, fakeFn);
      expect(result.died).toBe(true);
      expect(result.ship.alive).toBe(false);
      expect(result.ship.exploding).toBe(true);
      expect(result.ship.invulnTimer).toBe(0);
    });

    it("no death when randomFn returns >= WARP_DEATH_CHANCE", () => {
      const ship = {
        x: 100,
        y: 200,
        warpCooldown: 0,
        alive: true,
        exploding: false,
        invulnerable: false,
        invulnTimer: 0,
      };
      let callCount = 0;
      const fakeFn = () => {
        callCount++;
        if (callCount === 1) return 0.25; // >= 0.2 => survive
        return 0.5;
      };
      const result = attemptWarp(ship, fakeFn);
      expect(result.died).toBe(false);
    });

    it("new position is determined by randomFn", () => {
      const ship = {
        x: 100,
        y: 200,
        warpCooldown: 0,
        alive: true,
        exploding: false,
        invulnerable: false,
        invulnTimer: 0,
      };
      let callCount = 0;
      const fakeFn = () => {
        callCount++;
        if (callCount === 1) return 0.5; // death check
        if (callCount === 2) return 0.25; // x = 0.25 * CANVAS_W
        return 0.75; // y = 0.75 * CANVAS_H
      };
      const result = attemptWarp(ship, fakeFn);
      expect(result.ship.x).toBeCloseTo(0.25 * CANVAS_W);
      expect(result.ship.y).toBeCloseTo(0.75 * CANVAS_H);
    });
  });

  describe("spawnShips", () => {
    it("resets ship positions to initial spawn", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      state.ship1.x = 500;
      state.ship1.y = 400;
      state.ship2.x = 50;
      state.ship2.y = 50;
      const result = spawnShips(state);
      expect(result.ship1.x).toBe(160);
      expect(result.ship1.y).toBe(240);
      expect(result.ship2.x).toBe(480);
      expect(result.ship2.y).toBe(240);
    });

    it("preserves scores", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      state.score1 = 3;
      state.score2 = 5;
      const result = spawnShips(state);
      expect(result.score1).toBe(3);
      expect(result.score2).toBe(5);
    });

    it("clears missiles", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      state.missiles = [{ x: 0, y: 0, vx: 0, vy: 0, owner: 1, age: 0 }];
      const result = spawnShips(state);
      expect(result.missiles).toHaveLength(0);
    });

    it("ships are invulnerable after respawn", () => {
      const state = createInitialState(GAME_MODE.OPEN_SPACE);
      const result = spawnShips(state);
      expect(result.ship1.invulnerable).toBe(true);
      expect(result.ship2.invulnerable).toBe(true);
      expect(result.ship1.invulnTimer).toBe(SPAWN_INVULN);
      expect(result.ship2.invulnTimer).toBe(SPAWN_INVULN);
    });
  });

  describe("applyGravity", () => {
    it("pulls toward star (vx increases toward star from left side)", () => {
      const ship = { x: 100, y: STAR_Y, vx: 0, vy: 0 };
      const result = applyGravity(ship, STAR_X, STAR_Y);
      expect(result.vx).toBeGreaterThan(0);
      expect(result.vy).toBeCloseTo(0, 5);
    });

    it("pulls toward star (vx decreases toward star from right side)", () => {
      const ship = { x: 500, y: STAR_Y, vx: 0, vy: 0 };
      const result = applyGravity(ship, STAR_X, STAR_Y);
      expect(result.vx).toBeLessThan(0);
    });

    it("stronger force closer to star", () => {
      const shipClose = { x: STAR_X - 50, y: STAR_Y, vx: 0, vy: 0 };
      const shipFar = { x: STAR_X - 200, y: STAR_Y, vx: 0, vy: 0 };
      const resultClose = applyGravity(shipClose, STAR_X, STAR_Y);
      const resultFar = applyGravity(shipFar, STAR_X, STAR_Y);
      expect(resultClose.vx).toBeGreaterThan(resultFar.vx);
    });

    it("force clamp at close range (dist=2)", () => {
      // When dist is very small (2), force = GRAVITY_CONSTANT / (2^2) = 800/4 = 200
      // This exceeds MAX_SPEED (6), so it should be clamped to MAX_SPEED
      const ship = { x: STAR_X - 2, y: STAR_Y, vx: 0, vy: 0 };
      const result = applyGravity(ship, STAR_X, STAR_Y);
      // Force is clamped to MAX_SPEED, applied in x direction
      expect(result.vx).toBeCloseTo(MAX_SPEED);
      expect(result.vy).toBeCloseTo(0, 5);
    });

    it("no change when ship is at star position (dist < 1)", () => {
      const ship = { x: STAR_X, y: STAR_Y, vx: 3, vy: 4 };
      const result = applyGravity(ship, STAR_X, STAR_Y);
      expect(result.vx).toBe(3);
      expect(result.vy).toBe(4);
    });
  });

  describe("applyGravityToMissile", () => {
    it("pulls missile toward star", () => {
      const missile = { x: 100, y: STAR_Y, vx: 0, vy: 0 };
      const result = applyGravityToMissile(missile, STAR_X, STAR_Y);
      expect(result.vx).toBeGreaterThan(0);
      expect(result.vy).toBeCloseTo(0, 5);
    });

    it("preserves other missile properties", () => {
      const missile = { x: 100, y: STAR_Y, vx: 5, vy: -3, owner: 1, age: 10 };
      const result = applyGravityToMissile(missile, STAR_X, STAR_Y);
      expect(result.owner).toBe(1);
      expect(result.age).toBe(10);
      expect(result.vx).toBeGreaterThan(5); // pulled right toward star
    });

    it("no change when missile is at star (dist < 1)", () => {
      const missile = { x: STAR_X, y: STAR_Y, vx: 2, vy: 3 };
      const result = applyGravityToMissile(missile, STAR_X, STAR_Y);
      expect(result.vx).toBe(2);
      expect(result.vy).toBe(3);
    });

    it("force is clamped at close range", () => {
      const missile = { x: STAR_X - 2, y: STAR_Y, vx: 0, vy: 0 };
      const result = applyGravityToMissile(missile, STAR_X, STAR_Y);
      // Same clamp as ship gravity
      expect(result.vx).toBeCloseTo(MAX_SPEED);
    });
  });

  describe("checkStarCollision", () => {
    it("detects collision inside danger radius", () => {
      const ship = { x: STAR_X + 10, y: STAR_Y, alive: true, invulnerable: false };
      const result = checkStarCollision(ship);
      expect(result).toBe(true);
    });

    it("no collision outside danger radius", () => {
      const ship = {
        x: STAR_X + STAR_DANGER_RADIUS + 10,
        y: STAR_Y,
        alive: true,
        invulnerable: false,
      };
      const result = checkStarCollision(ship);
      expect(result).toBe(false);
    });

    it("no collision when ship is dead", () => {
      const ship = { x: STAR_X, y: STAR_Y, alive: false, invulnerable: false };
      const result = checkStarCollision(ship);
      expect(result).toBe(false);
    });

    it("no collision when ship is invulnerable", () => {
      const ship = { x: STAR_X, y: STAR_Y, alive: true, invulnerable: true };
      const result = checkStarCollision(ship);
      expect(result).toBe(false);
    });
  });

  describe("generateAsteroids", () => {
    it("deterministic — same seed produces same asteroids", () => {
      const a1 = generateAsteroids(42);
      const a2 = generateAsteroids(42);
      expect(a1.length).toBe(a2.length);
      for (let i = 0; i < a1.length; i++) {
        expect(a1[i].x).toBe(a2[i].x);
        expect(a1[i].y).toBe(a2[i].y);
        expect(a1[i].radius).toBe(a2[i].radius);
      }
    });

    it("produces ASTEROID_COUNT asteroids", () => {
      const asteroids = generateAsteroids(123);
      expect(asteroids).toHaveLength(ASTEROID_COUNT);
    });

    it("each asteroid has x, y, radius, and vertices array", () => {
      const asteroids = generateAsteroids(99);
      for (const a of asteroids) {
        expect(typeof a.x).toBe("number");
        expect(typeof a.y).toBe("number");
        expect(typeof a.radius).toBe("number");
        expect(Array.isArray(a.vertices)).toBe(true);
        expect(a.vertices.length).toBeGreaterThanOrEqual(8);
      }
    });

    it("asteroid radii are within min/max range", () => {
      const asteroids = generateAsteroids(77);
      for (const a of asteroids) {
        expect(a.radius).toBeGreaterThanOrEqual(ASTEROID_MIN_RADIUS);
        expect(a.radius).toBeLessThanOrEqual(ASTEROID_MAX_RADIUS);
      }
    });

    it("different seeds produce different asteroids", () => {
      const a1 = generateAsteroids(1);
      const a2 = generateAsteroids(2);
      const same = a1.every((a, i) => a.x === a2[i].x && a.y === a2[i].y);
      expect(same).toBe(false);
    });

    it("asteroids do not overlap each other", () => {
      // Test with several seeds
      for (const seed of [42, 100, 999, 7777]) {
        const asteroids = generateAsteroids(seed);
        for (let i = 0; i < asteroids.length; i++) {
          for (let j = i + 1; j < asteroids.length; j++) {
            const a = asteroids[i];
            const b = asteroids[j];
            const dx = a.x - b.x;
            const dy = a.y - b.y;
            const dist = Math.sqrt(dx * dx + dy * dy);
            // Minimum separation is radius_a + radius_b + 4 (the padding constant)
            expect(dist).toBeGreaterThanOrEqual(a.radius + b.radius + 4);
          }
        }
      }
    });
  });

  describe("checkAsteroidShipCollision", () => {
    it("detects collision when ship overlaps asteroid", () => {
      const asteroids = [{ x: 100, y: 200, radius: 20 }];
      const ship = { x: 110, y: 200, alive: true, invulnerable: false };
      const result = checkAsteroidShipCollision(ship, asteroids);
      expect(result).toBe(true);
    });

    it("no collision when ship is far from asteroids", () => {
      const asteroids = [{ x: 100, y: 200, radius: 20 }];
      const ship = { x: 400, y: 400, alive: true, invulnerable: false };
      const result = checkAsteroidShipCollision(ship, asteroids);
      expect(result).toBe(false);
    });

    it("no collision when ship is dead", () => {
      const asteroids = [{ x: 100, y: 200, radius: 20 }];
      const ship = { x: 100, y: 200, alive: false, invulnerable: false };
      const result = checkAsteroidShipCollision(ship, asteroids);
      expect(result).toBe(false);
    });

    it("no collision when ship is invulnerable", () => {
      const asteroids = [{ x: 100, y: 200, radius: 20 }];
      const ship = { x: 100, y: 200, alive: true, invulnerable: true };
      const result = checkAsteroidShipCollision(ship, asteroids);
      expect(result).toBe(false);
    });
  });

  describe("checkAsteroidMissileCollision", () => {
    it("removes missiles that hit asteroids", () => {
      const asteroids = [{ x: 100, y: 200, radius: 20 }];
      const missiles = [
        { x: 105, y: 200, vx: 0, vy: 0, owner: 1, age: 0 },
        { x: 500, y: 500, vx: 0, vy: 0, owner: 2, age: 0 },
      ];
      const result = checkAsteroidMissileCollision(missiles, asteroids);
      expect(result).toHaveLength(1);
      expect(result[0].x).toBe(500);
    });

    it("keeps missiles that miss asteroids", () => {
      const asteroids = [{ x: 100, y: 200, radius: 20 }];
      const missiles = [{ x: 400, y: 400, vx: 0, vy: 0, owner: 1, age: 0 }];
      const result = checkAsteroidMissileCollision(missiles, asteroids);
      expect(result).toHaveLength(1);
    });
  });

  describe("createExplosionParticles", () => {
    it("creates correct count with default", () => {
      const particles = createExplosionParticles(100, 200);
      expect(particles).toHaveLength(15);
    });

    it("creates specified count", () => {
      const particles = createExplosionParticles(100, 200, 10);
      expect(particles).toHaveLength(10);
    });

    it("particles start at given position", () => {
      const particles = createExplosionParticles(150, 250);
      for (const p of particles) {
        expect(p.x).toBe(150);
        expect(p.y).toBe(250);
      }
    });

    it("particles have velocity and life", () => {
      const particles = createExplosionParticles(0, 0);
      for (const p of particles) {
        expect(typeof p.vx).toBe("number");
        expect(typeof p.vy).toBe("number");
        expect(p.life).toBe(1.0);
      }
    });

    it("deterministic with custom randomFn", () => {
      let seed = 0;
      const fakeFn = () => {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed / 0x7fffffff;
      };

      seed = 0;
      const p1 = createExplosionParticles(50, 75, 5, fakeFn);

      seed = 0;
      const p2 = createExplosionParticles(50, 75, 5, fakeFn);

      expect(p1).toHaveLength(5);
      expect(p2).toHaveLength(5);
      for (let i = 0; i < 5; i++) {
        expect(p1[i].vx).toBe(p2[i].vx);
        expect(p1[i].vy).toBe(p2[i].vy);
      }
    });
  });

  describe("updateParticles", () => {
    it("moves particles by velocity", () => {
      const particles = [{ x: 10, y: 20, vx: 3, vy: -2, life: 1.0 }];
      const result = updateParticles(particles);
      expect(result[0].x).toBeCloseTo(13);
      expect(result[0].y).toBeCloseTo(18);
    });

    it("decays life by 0.03 per tick", () => {
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 1.0 }];
      const result = updateParticles(particles);
      expect(result[0].life).toBeCloseTo(0.97);
    });

    it("removes dead particles (life <= 0)", () => {
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 0.02 }];
      const result = updateParticles(particles);
      expect(result).toHaveLength(0);
    });

    it("applies drag (0.96) to velocity", () => {
      const particles = [{ x: 0, y: 0, vx: 10, vy: 10, life: 1.0 }];
      const result = updateParticles(particles);
      expect(result[0].vx).toBeCloseTo(10 * 0.96);
      expect(result[0].vy).toBeCloseTo(10 * 0.96);
    });
  });

  describe("toroidal distance (via checkShipShipCollision)", () => {
    it("ships at opposite edges are close via wraparound", () => {
      // Ship1 at x=1, ship2 at x=639 (CANVAS_W-1) — direct distance is 638
      // but toroidal distance is 2 (wraps around)
      const ship1 = { x: 1, y: 240, alive: true, invulnerable: false };
      const ship2 = { x: CANVAS_W - 1, y: 240, alive: true, invulnerable: false };
      // Direct distance is 638, but toroidal distance is 2 which is < 2*SHIP_RADIUS=24
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(true);
    });

    it("ships at opposite vertical edges are close via wraparound", () => {
      const ship1 = { x: 320, y: 1, alive: true, invulnerable: false };
      const ship2 = { x: 320, y: CANVAS_H - 1, alive: true, invulnerable: false };
      // Toroidal distance in y is 2, which is < 2*SHIP_RADIUS
      const result = checkShipShipCollision(ship1, ship2);
      expect(result).toBe(true);
    });
  });
});
