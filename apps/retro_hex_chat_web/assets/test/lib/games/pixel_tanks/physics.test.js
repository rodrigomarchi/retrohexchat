import { describe, it, expect } from "vitest";
import {
  GRID_COLS,
  GRID_ROWS,
  MISSILE_LIFETIME,
  WALL_SIZE,
  updateMissileRicochet,
} from "../../../../js/lib/games/pixel_tanks/physics.js";

const open = () => new Uint8Array(GRID_COLS * GRID_ROWS);
const shell = (fields) => ({
  m1Active: true,
  m1X: 100,
  m1Y: 100,
  m1VX: 3,
  m1VY: 0,
  m1Age: 0,
  m1Bounced: false,
  tank1Cooldown: 0,
  ...fields,
});

describe("a ricocheting shell", () => {
  it("leaves a state with no shell in flight as it is", () => {
    const state = shell({ m1Active: false });
    expect(updateMissileRicochet(state, 1, open())).toBe(state);
  });

  it("flies straight through open ground", () => {
    expect(updateMissileRicochet(shell(), 1, open())).toMatchObject({
      m1X: 103,
      m1Y: 100,
      m1Age: 1,
    });
  });

  it("burns out at the end of its life", () => {
    const next = updateMissileRicochet(shell({ m1Age: MISSILE_LIFETIME - 1 }), 1, open());
    expect(next).toMatchObject({ m1Active: false, missileExpired: 1 });
    expect(next.tank1Cooldown).toBeGreaterThan(0);
  });

  it("bounces once off the edge of the arena, then is spent on the next wall", () => {
    const edge = GRID_COLS * WALL_SIZE - 2;
    const bounced = updateMissileRicochet(shell({ m1X: edge }), 1, open());
    expect(bounced).toMatchObject({ m1VX: -3, m1Bounced: true, wallBounced: 1 });

    const walls = open();
    walls[Math.floor(100 / WALL_SIZE) * GRID_COLS + Math.floor(106 / WALL_SIZE)] = 1;
    const spent = updateMissileRicochet(shell({ m1X: 100, m1Bounced: true }), 1, walls);
    expect(spent).toMatchObject({ m1Active: false, missileExpired: 1 });
  });

  it("turns back off a wall it flies into side-on", () => {
    const walls = open();
    const row = Math.floor(100 / WALL_SIZE);
    walls[row * GRID_COLS + Math.floor(103 / WALL_SIZE) + 1] = 1;
    const x = (Math.floor(103 / WALL_SIZE) + 1) * WALL_SIZE - 2;
    expect(updateMissileRicochet(shell({ m1X: x }), 1, walls)).toMatchObject({
      m1VX: -3,
      m1Bounced: true,
    });
  });
});
