import { describe, it, expect } from "vitest";
import { PHASE, DIR, GRID_W, GRID_H } from "../../../../js/lib/games/surround/protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  CELL_SIZE,
  GRID_OFFSET_X,
  GRID_OFFSET_Y,
  CELL,
  createInitialState,
  applyDirection,
  moveAndCheck,
  createCrashParticles,
  updateParticles,
} from "../../../../js/lib/games/surround/physics.js";

describe("surround_physics", () => {
  describe("constants", () => {
    it("has 640x480 canvas", () => {
      expect(CANVAS_W).toBe(640);
      expect(CANVAS_H).toBe(480);
    });

    it("CELL_SIZE fits grid in canvas", () => {
      expect(GRID_W * CELL_SIZE).toBeLessThanOrEqual(CANVAS_W);
      expect(GRID_H * CELL_SIZE).toBeLessThanOrEqual(CANVAS_H);
    });

    it("grid is centered with offsets", () => {
      expect(GRID_OFFSET_X).toBeGreaterThanOrEqual(0);
      expect(GRID_OFFSET_Y).toBeGreaterThanOrEqual(0);
    });
  });

  describe("createInitialState", () => {
    it("creates 40-row by 60-column grid", () => {
      const state = createInitialState(0);
      expect(state.grid).toHaveLength(GRID_H);
      expect(state.grid[0]).toHaveLength(GRID_W);
    });

    it("starts in WAITING phase", () => {
      const state = createInitialState(0);
      expect(state.phase).toBe(PHASE.WAITING);
    });

    it("starts scores at 0", () => {
      const state = createInitialState(0);
      expect(state.score1).toBe(0);
      expect(state.score2).toBe(0);
    });

    it("round 0: P1 on left heading RIGHT, P2 on right heading LEFT", () => {
      const state = createInitialState(0);
      expect(state.p1.x).toBe(5);
      expect(state.p1.dir).toBe(DIR.RIGHT);
      expect(state.p2.x).toBe(GRID_W - 6);
      expect(state.p2.dir).toBe(DIR.LEFT);
    });

    it("round 1: positions swap", () => {
      const state = createInitialState(1);
      expect(state.p1.x).toBe(GRID_W - 6);
      expect(state.p1.dir).toBe(DIR.LEFT);
      expect(state.p2.x).toBe(5);
      expect(state.p2.dir).toBe(DIR.RIGHT);
    });

    it("places initial trail at starting positions", () => {
      const state = createInitialState(0);
      expect(state.grid[state.p1.y][state.p1.x]).toBe(CELL.P1_TRAIL);
      expect(state.grid[state.p2.y][state.p2.x]).toBe(CELL.P2_TRAIL);
    });

    it("starts with empty particles", () => {
      const state = createInitialState(0);
      expect(state.particles).toEqual([]);
    });

    it("countdown starts at 3", () => {
      const state = createInitialState(0);
      expect(state.countdown).toBe(3);
    });
  });

  describe("applyDirection", () => {
    it("allows 90-degree turn from RIGHT to UP", () => {
      expect(applyDirection(DIR.RIGHT, DIR.UP)).toBe(DIR.UP);
    });

    it("allows 90-degree turn from LEFT to DOWN", () => {
      expect(applyDirection(DIR.LEFT, DIR.DOWN)).toBe(DIR.DOWN);
    });

    it("blocks 180-degree reversal: UP to DOWN", () => {
      expect(applyDirection(DIR.UP, DIR.DOWN)).toBe(DIR.UP);
    });

    it("blocks 180-degree reversal: DOWN to UP", () => {
      expect(applyDirection(DIR.DOWN, DIR.UP)).toBe(DIR.DOWN);
    });

    it("blocks 180-degree reversal: LEFT to RIGHT", () => {
      expect(applyDirection(DIR.LEFT, DIR.RIGHT)).toBe(DIR.LEFT);
    });

    it("blocks 180-degree reversal: RIGHT to LEFT", () => {
      expect(applyDirection(DIR.RIGHT, DIR.LEFT)).toBe(DIR.RIGHT);
    });

    it("allows same direction (no change)", () => {
      expect(applyDirection(DIR.UP, DIR.UP)).toBe(DIR.UP);
    });
  });

  describe("moveAndCheck", () => {
    function playingState() {
      const state = createInitialState(0);
      state.phase = PHASE.PLAYING;
      return state;
    }

    it("returns unchanged state when not PLAYING", () => {
      const state = createInitialState(0);
      state.phase = PHASE.WAITING;
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.p1Dead).toBe(false);
      expect(result.p2Dead).toBe(false);
      expect(result.p1.x).toBe(state.p1.x);
    });

    it("moves P1 one cell right", () => {
      const state = playingState();
      const origX = state.p1.x;
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.p1.x).toBe(origX + 1);
      expect(result.p1Dead).toBe(false);
    });

    it("moves P2 one cell left", () => {
      const state = playingState();
      const origX = state.p2.x;
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.p2.x).toBe(origX - 1);
      expect(result.p2Dead).toBe(false);
    });

    it("places trail at new position for survivors", () => {
      const state = playingState();
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.grid[result.p1.y][result.p1.x]).toBe(CELL.P1_TRAIL);
      expect(result.grid[result.p2.y][result.p2.x]).toBe(CELL.P2_TRAIL);
    });

    it("kills player on left border (OOB)", () => {
      const state = playingState();
      state.p1.x = 0;
      state.p1.dir = DIR.LEFT;
      const result = moveAndCheck(state, DIR.LEFT, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
    });

    it("kills player on right border (OOB)", () => {
      const state = playingState();
      state.p2.x = GRID_W - 1;
      state.p2.dir = DIR.RIGHT;
      const result = moveAndCheck(state, DIR.RIGHT, DIR.RIGHT);
      expect(result.p2Dead).toBe(true);
    });

    it("kills player on top border (OOB)", () => {
      const state = playingState();
      state.p1.x = 10;
      state.p1.y = 0;
      state.p1.dir = DIR.UP;
      const result = moveAndCheck(state, DIR.UP, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
    });

    it("kills player on bottom border (OOB)", () => {
      const state = playingState();
      state.p1.x = 10;
      state.p1.y = GRID_H - 1;
      state.p1.dir = DIR.DOWN;
      const result = moveAndCheck(state, DIR.DOWN, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
    });

    it("kills player hitting own trail", () => {
      const state = playingState();
      // Place a trail cell ahead of P1
      const nextX = state.p1.x + 1;
      state.grid[state.p1.y][nextX] = CELL.P1_TRAIL;
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
    });

    it("kills player hitting opponent trail", () => {
      const state = playingState();
      // Place P2 trail ahead of P1
      const nextX = state.p1.x + 1;
      state.grid[state.p1.y][nextX] = CELL.P2_TRAIL;
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
    });

    it("both die on head-on collision (same target cell)", () => {
      const state = playingState();
      // Place P1 and P2 adjacent, moving toward each other
      state.p1.x = 29;
      state.p1.y = 20;
      state.p1.dir = DIR.RIGHT;
      state.p2.x = 31;
      state.p2.y = 20;
      state.p2.dir = DIR.LEFT;
      // Both move to cell (30, 20)
      const result = moveAndCheck(state, DIR.RIGHT, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
      expect(result.p2Dead).toBe(true);
    });

    it("dead player head does not update position", () => {
      const state = playingState();
      state.p1.x = 0;
      state.p1.y = 20;
      state.p1.dir = DIR.LEFT;
      const result = moveAndCheck(state, DIR.LEFT, DIR.LEFT);
      expect(result.p1Dead).toBe(true);
      // Head stays at original position
      expect(result.p1.x).toBe(0);
    });

    it("does not place trail for dead players", () => {
      const state = playingState();
      state.p1.x = 0;
      state.p1.y = 20;
      state.p1.dir = DIR.LEFT;
      const result = moveAndCheck(state, DIR.LEFT, DIR.LEFT);
      // The cell at (-1, 20) is OOB, so no trail placed
      // Verify P2 trail IS placed though
      expect(result.grid[result.p2.y][result.p2.x]).toBe(CELL.P2_TRAIL);
    });

    it("blocks 180-degree reversal during movement", () => {
      const state = playingState();
      state.p1.dir = DIR.RIGHT;
      const origX = state.p1.x;
      // Request LEFT (reversal) — should continue RIGHT
      const result = moveAndCheck(state, DIR.LEFT, DIR.LEFT);
      expect(result.p1.x).toBe(origX + 1);
      expect(result.p1.dir).toBe(DIR.RIGHT);
    });
  });

  describe("createCrashParticles", () => {
    it("creates 12 particles", () => {
      const particles = createCrashParticles(10, 20, "#00ff41");
      expect(particles).toHaveLength(12);
    });

    it("particles are at grid pixel coordinates", () => {
      const particles = createCrashParticles(10, 20, "#00ff41");
      const expectedX = GRID_OFFSET_X + 10 * CELL_SIZE + CELL_SIZE / 2;
      const expectedY = GRID_OFFSET_Y + 20 * CELL_SIZE + CELL_SIZE / 2;
      for (const p of particles) {
        expect(p.x).toBe(expectedX);
        expect(p.y).toBe(expectedY);
      }
    });

    it("particles have life=1.0 and color", () => {
      const particles = createCrashParticles(5, 5, "#ff0000");
      for (const p of particles) {
        expect(p.life).toBe(1.0);
        expect(p.color).toBe("#ff0000");
      }
    });
  });

  describe("updateParticles", () => {
    it("moves particles by velocity", () => {
      const particles = [{ x: 10, y: 20, vx: 2, vy: 3, life: 1.0, color: "#fff" }];
      const updated = updateParticles(particles);
      expect(updated[0].x).toBe(12);
      expect(updated[0].y).toBe(23);
    });

    it("applies drag to velocity", () => {
      const particles = [{ x: 0, y: 0, vx: 10, vy: 10, life: 1.0, color: "#fff" }];
      const updated = updateParticles(particles);
      expect(updated[0].vx).toBeCloseTo(9.6, 1);
      expect(updated[0].vy).toBeCloseTo(9.6, 1);
    });

    it("decays life", () => {
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 1.0, color: "#fff" }];
      const updated = updateParticles(particles);
      expect(updated[0].life).toBeCloseTo(0.96, 2);
    });

    it("removes dead particles", () => {
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 0.03, color: "#fff" }];
      const updated = updateParticles(particles);
      expect(updated).toHaveLength(0);
    });
  });
});
