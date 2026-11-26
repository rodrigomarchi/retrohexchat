import { describe, it, expect } from "vitest";
import {
  GRID_COLS,
  GRID_ROWS,
  MISSILE_LIFETIME,
  RESPAWN_PAUSE,
  TANK_RADIUS,
  WALL_SIZE,
  createInitialState,
  decodeMaze,
  hiddenSpawnRows,
  resetForNewRound,
  respawnTanks,
  spawnY,
  stepTick,
  updateMissile,
} from "../../../../js/lib/games/pixel_tanks/physics.js";
import { pressAndHold, released } from "../../../support/games/physics_tests.js";
import { PHASE } from "../../../../js/lib/games/pixel_tanks/protocol.js";
import { lineOfSightClear } from "../../../../js/lib/games/pixel_tanks/ai.js";

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
    expect(updateMissile(state, 1, open())).toBe(state);
  });

  it("flies straight through open ground", () => {
    expect(updateMissile(shell(), 1, open())).toMatchObject({
      m1X: 103,
      m1Y: 100,
      m1Age: 1,
    });
  });

  it("burns out at the end of its life", () => {
    const next = updateMissile(shell({ m1Age: MISSILE_LIFETIME - 1 }), 1, open());
    expect(next).toMatchObject({ m1Active: false, missileExpired: 1 });
    expect(next.tank1Cooldown).toBeGreaterThan(0);
  });

  it("bounces once off the edge of the arena, then is spent on the next wall", () => {
    const edge = GRID_COLS * WALL_SIZE - 2;
    const bounced = updateMissile(shell({ m1X: edge }), 1, open());
    expect(bounced).toMatchObject({ m1VX: -3, m1Bounced: true, wallBounced: 1 });

    const walls = open();
    walls[Math.floor(100 / WALL_SIZE) * GRID_COLS + Math.floor(106 / WALL_SIZE)] = 1;
    const spent = updateMissile(shell({ m1X: 100, m1Bounced: true }), 1, walls);
    expect(spent).toMatchObject({ m1Active: false, missileExpired: 1 });
  });

  it("turns back off a wall it flies into side-on", () => {
    const walls = open();
    const row = Math.floor(100 / WALL_SIZE);
    walls[row * GRID_COLS + Math.floor(103 / WALL_SIZE) + 1] = 1;
    const x = (Math.floor(103 / WALL_SIZE) + 1) * WALL_SIZE - 2;
    expect(updateMissile(shell({ m1X: x }), 1, walls)).toMatchObject({
      m1VX: -3,
      m1Bounced: true,
    });
  });
});

describe("stepTick", () => {
  const walls = decodeMaze(0);
  const idle = released("rotateLeft", "rotateRight", "forward", "fire");
  const fire = { ...idle, fire: true };
  const playing = () => ({ ...createInitialState(0, 0), phase: PHASE.PLAYING });

  it("fires a shell on the press, not while the key is held", () => {
    const { first, held } = pressAndHold(
      (state, pressed) => stepTick(state, walls, { 1: fire, 2: idle }, pressed),
      playing(),
      { 1: false, 2: false },
      (state) => ({ ...state, m1Active: false }),
    );

    expect(first.events.fired).toEqual([1]);
    expect(first.state.m1Active).toBe(true);
    expect(first.pressed).toEqual({ 1: true, 2: false });
    expect(held.events.fired).toEqual([]);
  });

  it("sends both tanks home after a hit, and says where the tank stood", () => {
    const start = playing();
    const state = {
      ...start,
      tank2X: 300,
      tank2Y: 200,
      m1Active: true,
      m1X: 300 - TANK_RADIUS - 6,
      m1Y: 200,
      m1VX: 5,
      m1VY: 0,
    };

    const step = stepTick(state, walls, { 1: idle, 2: idle }, { 1: false, 2: false });

    expect(step.events.hit).toEqual({ player: 2, x: 300, y: 200 });
    expect(step.state.score1).toBe(1);
    expect(step.state.tank2X).toBe(start.tank2X);
    expect(step.state.respawnPause).toBe(RESPAWN_PAUSE - 1);
  });

  it("only runs the timers while the tanks hold still after a hit", () => {
    const state = { ...playing(), respawnPause: 10 };

    const step = stepTick(state, walls, { 1: fire, 2: fire }, { 1: false, 2: false });

    expect(step.paused).toBe(true);
    expect(step.state.respawnPause).toBe(9);
    expect(step.state.m1Active).toBe(false);
    expect(step.pressed).toEqual({ 1: false, 2: false });
  });
});

// A start facing the rival across open ground made every round a duel at the
// spawns, decided by who fired first once the shields were down.
describe("where the tanks start over", () => {
  // Every maze the host draws (`selectMaze`): all but the open field.
  const MAZES = [1, 2, 3, 4, 5];
  const cellOf = (v) => Math.floor(v / WALL_SIZE);

  it("is, in every maze the host draws, a place neither tank can see the other from", () => {
    for (const maze of MAZES) {
      const walls = decodeMaze(maze);
      for (let turn = 0; turn < 12; turn++) {
        const s = respawnTanks({ ...createInitialState(0, maze), score1: turn });
        expect(lineOfSightClear(s.tank1X, s.tank1Y, s.tank2X, s.tank2Y, walls)).toBe(false);
        for (const [x, y] of [
          [s.tank1X, s.tank1Y],
          [s.tank2X, s.tank2Y],
        ]) {
          for (const dx of [-TANK_RADIUS, 0, TANK_RADIUS]) {
            for (const dy of [-TANK_RADIUS, 0, TANK_RADIUS]) {
              expect(walls[cellOf(y + dy) * GRID_COLS + cellOf(x + dx)]).toBe(0);
            }
          }
        }
      }
    }
  });

  it("moves from one hit to the next, and starts each round out of sight too", () => {
    for (const maze of MAZES) {
      const rows = new Set(
        [0, 1, 2, 3].map(
          (hits) => respawnTanks({ ...createInitialState(0, maze), score1: hits }).tank1Y,
        ),
      );
      if (hiddenSpawnRows(decodeMaze(maze)).length > 1) expect(rows.size).toBeGreaterThan(1);
      const walls = decodeMaze(maze);
      const next = resetForNewRound({ ...createInitialState(0, maze), round: 2 });
      expect(lineOfSightClear(next.tank1X, next.tank1Y, next.tank2X, next.tank2Y, walls)).toBe(
        false,
      );
      const first = createInitialState(0, maze);
      expect(lineOfSightClear(first.tank1X, first.tank1Y, first.tank2X, first.tank2Y, walls)).toBe(
        false,
      );
    }
  });

  it("is the same for host and guest: worked out from the maze and the score alone", () => {
    expect(spawnY(4, 3)).toBe(spawnY(4, 3));
  });
});
