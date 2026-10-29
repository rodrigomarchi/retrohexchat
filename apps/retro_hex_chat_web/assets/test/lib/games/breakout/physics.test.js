import { describe, it, expect } from "vitest";
import { PHASE, TOTAL_BLOCKS, BLOCK_ROWS } from "../../../../js/lib/games/breakout/protocol.js";
import * as physics from "../../../../js/lib/games/breakout/physics.js";
import {
  CANVAS_W,
  CANVAS_H,
  PADDLE_W,
  PADDLE_H,
  PADDLE_MARGIN,
  BALL_SIZE,
  INITIAL_BALL_SPEED,
  MAX_BALL_SPEED,
  SPEED_INCREMENT,
  INITIAL_LIVES,
  ROW_POINTS,
  createBlockGrid,
  createInitialState,
  checkPaddleCollision,
  checkBlockCollision,
  checkLifeLost,
  checkWin,
  serveBall,
  createBlockParticles,
  stepTick,
  serveAfter,
} from "../../../../js/lib/games/breakout/physics.js";
import {
  HORIZONTAL_AXIS,
  initialStateTests,
  particleBurstTests,
  playingState,
  serveBallTests,
  stepTickMovesTest,
  updateBallTests,
  updateParticlesTests,
  updatePaddleTests,
  wallBounceTests,
} from "../../../support/games/physics_tests.js";

const game = { physics, PHASE, axis: HORIZONTAL_AXIS };

/** Left edge of a paddle at its starting place. */
const PADDLE_LEFT = (CANVAS_W - PADDLE_W) / 2;
/** Centre of a paddle at its starting place. */
const PADDLE_CENTER_X = PADDLE_LEFT + PADDLE_W / 2;
/** Top face of the bottom paddle (P1). */
const P1_TOP = CANVAS_H - PADDLE_MARGIN - PADDLE_H;
/** Ball y just inside the bottom paddle's face. */
const P1_HIT_Y = P1_TOP - BALL_SIZE / 2 + 1;

/**
 * A playing ball over the centre of the starting paddles, just inside the
 * bottom paddle's face and falling straight onto it at speed 5, with
 * `overrides` applied.
 * @param {object} [overrides]
 */
function paddleBallState(overrides = {}) {
  return playingState(game, {
    ballX: PADDLE_CENTER_X,
    ballY: P1_HIT_Y,
    ballVX: 0,
    ballVY: 5,
    ballSpeed: 5,
    ...overrides,
  });
}

/**
 * A playing ball in the middle of the first block of `state`, rising at
 * speed 4, with `overrides` applied.
 * @param {object} state
 * @param {object} [overrides]
 */
function inFirstBlock(state, overrides = {}) {
  const block = state.blocks[0];
  return {
    ...state,
    ballX: block.x + block.w / 2,
    ballY: block.y + block.h / 2,
    ballVX: 0,
    ballVY: -4,
    phase: PHASE.PLAYING,
    ...overrides,
  };
}

/**
 * The block check on a fresh state with the ball in the middle of the first
 * block (see `inFirstBlock`).
 * @param {object} [overrides]
 */
function hitFirstBlock(overrides = {}) {
  return checkBlockCollision(inFirstBlock(createInitialState(), overrides));
}

/**
 * The life check on a fresh state with `overrides` applied.
 * @param {object} overrides
 */
function lifeCheck(overrides) {
  return checkLifeLost({ ...createInitialState(), ...overrides });
}

/**
 * The win check on a fresh state with `overrides` applied.
 * @param {object} overrides
 */
function winCheck(overrides) {
  return checkWin({ ...createInitialState(), ...overrides });
}

describe("breakout_physics", () => {
  describe("createBlockGrid", () => {
    it("creates 50 blocks", () => {
      const blocks = createBlockGrid();
      expect(blocks).toHaveLength(TOTAL_BLOCKS);
    });

    it("all blocks start alive", () => {
      const blocks = createBlockGrid();
      expect(blocks.every((b) => b.alive)).toBe(true);
    });

    it("has correct number of rows", () => {
      const blocks = createBlockGrid();
      const rows = new Set(blocks.map((b) => b.row));
      expect(rows.size).toBe(BLOCK_ROWS);
    });

    it("assigns points by row", () => {
      const blocks = createBlockGrid();
      for (const block of blocks) {
        expect(block.points).toBe(ROW_POINTS[block.row]);
      }
    });

    it("blocks have position and size", () => {
      const blocks = createBlockGrid();
      for (const block of blocks) {
        expect(block.x).toBeGreaterThanOrEqual(0);
        expect(block.y).toBeGreaterThan(0);
        expect(block.w).toBeGreaterThan(0);
        expect(block.h).toBeGreaterThan(0);
      }
    });
  });

  describe("createInitialState", () => {
    initialStateTests(game);

    it("starts with 3 lives", () => {
      const state = createInitialState();
      expect(state.lives).toBe(INITIAL_LIVES);
    });

    it("starts with zero score", () => {
      const state = createInitialState();
      expect(state.score).toBe(0);
    });

    it("starts with all 50 blocks", () => {
      const state = createInitialState();
      expect(state.blocksRemaining).toBe(TOTAL_BLOCKS);
      expect(state.blocks).toHaveLength(TOTAL_BLOCKS);
    });
  });

  updatePaddleTests(game);
  updateBallTests(game);
  wallBounceTests(game);

  describe("checkPaddleCollision", () => {
    it("bounces off bottom paddle (P1)", () => {
      const result = checkPaddleCollision(paddleBallState());
      expect(result.ballVY).toBeLessThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("bounces off top paddle (P2)", () => {
      const p2Bottom = PADDLE_MARGIN + PADDLE_H;
      const result = checkPaddleCollision(
        paddleBallState({ ballY: p2Bottom + BALL_SIZE / 2 - 1, ballVY: -5 }),
      );
      expect(result.ballVY).toBeGreaterThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("does not collide when ball moves away from paddle", () => {
      const away = paddleBallState({ ballY: P1_TOP - 10, ballVY: -5 });
      expect(checkPaddleCollision(away).paddleHit).toBeFalsy();
    });

    it("increments ball speed on paddle hit", () => {
      const result = checkPaddleCollision(paddleBallState({ ballSpeed: INITIAL_BALL_SPEED }));
      expect(result.ballSpeed).toBe(INITIAL_BALL_SPEED + SPEED_INCREMENT);
    });

    it("does not exceed MAX_BALL_SPEED on paddle hit", () => {
      const state = paddleBallState({ ballVY: MAX_BALL_SPEED, ballSpeed: MAX_BALL_SPEED });
      expect(checkPaddleCollision(state).ballSpeed).toBeLessThanOrEqual(MAX_BALL_SPEED);
    });

    it("creates steeper angle on edge hit", () => {
      const resultEdge = checkPaddleCollision(paddleBallState({ ballX: PADDLE_LEFT }));
      const resultCenter = checkPaddleCollision(paddleBallState({ ballX: PADDLE_CENTER_X }));

      expect(Math.abs(resultEdge.ballVX)).toBeGreaterThan(Math.abs(resultCenter.ballVX));
    });
  });

  describe("checkBlockCollision", () => {
    it("destroys block on collision", () => {
      const result = hitFirstBlock();
      expect(result.blocks[0].alive).toBe(false);
      expect(result.blocksRemaining).toBe(TOTAL_BLOCKS - 1);
      expect(result.blocksDestroyed).toBe(1);
    });

    it("adds score from destroyed block", () => {
      // Row 0 = 50 pts
      expect(hitFirstBlock().score).toBe(ROW_POINTS[0]);
    });

    it("sets blockHit flag", () => {
      const result = hitFirstBlock();
      expect(result.blockHit).toBe(true);
      expect(result.hitBlockRow).toBe(0);
    });

    it("reverses ball direction on collision", () => {
      const block = createInitialState().blocks[0];
      const result = hitFirstBlock({ ballY: block.y + block.h + BALL_SIZE / 2 - 1 });
      expect(result.ballVY).toBe(4);
    });

    it("does not collide with dead blocks", () => {
      const state = createInitialState();
      state.blocks = state.blocks.map((b, i) => (i === 0 ? { ...b, alive: false } : b));
      const result = checkBlockCollision(inFirstBlock(state));
      expect(result.blockHit).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      const result = hitFirstBlock({ phase: createInitialState().phase });
      expect(result.blockHit).toBeFalsy();
    });

    it("speeds up ball every 5 blocks destroyed", () => {
      const result = hitFirstBlock({
        ballVY: -INITIAL_BALL_SPEED,
        ballSpeed: INITIAL_BALL_SPEED,
        blocksDestroyed: 4, // This will be the 5th
      });
      expect(result.ballSpeed).toBeGreaterThan(INITIAL_BALL_SPEED);
    });

    it("does not exceed MAX_BALL_SPEED from block speedup", () => {
      const result = hitFirstBlock({
        ballVY: -MAX_BALL_SPEED,
        ballSpeed: MAX_BALL_SPEED,
        blocksDestroyed: 4,
      });
      expect(result.ballSpeed).toBeLessThanOrEqual(MAX_BALL_SPEED);
    });

    it("bounces ball horizontally on side collision", () => {
      const block = createInitialState().blocks[0];
      // Hit from the left side of the block
      const result = hitFirstBlock({ ballX: block.x - BALL_SIZE / 2 + 1, ballVX: 3, ballVY: -1 });
      expect(result.blockHit).toBe(true);
      expect(result.ballVX).toBe(-3);
    });

    it("provides hit block color for particles", () => {
      const block = createInitialState().blocks[0];
      expect(hitFirstBlock().hitBlockColor).toBe(block.color);
    });
  });

  describe("checkLifeLost", () => {
    it("loses life when ball exits bottom", () => {
      const result = lifeCheck({ ballY: CANVAS_H - BALL_SIZE / 2 + 1, phase: PHASE.PLAYING });
      expect(result.lives).toBe(INITIAL_LIVES - 1);
      expect(result.phase).toBe(PHASE.LIFE_LOST);
      expect(result.lifeLost).toBe(true);
    });

    it("loses life when ball exits top", () => {
      const result = lifeCheck({ ballY: BALL_SIZE / 2 - 1, phase: PHASE.PLAYING });
      expect(result.lives).toBe(INITIAL_LIVES - 1);
      expect(result.phase).toBe(PHASE.LIFE_LOST);
    });

    it("does not lose life when ball is in play area", () => {
      const result = lifeCheck({ ballY: CANVAS_H / 2, phase: PHASE.PLAYING });
      expect(result.lives).toBe(INITIAL_LIVES);
      expect(result.lifeLost).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      expect(lifeCheck({ ballY: CANVAS_H + 10 }).lives).toBe(INITIAL_LIVES);
    });
  });

  describe("checkWin", () => {
    it("wins when all blocks destroyed", () => {
      const result = winCheck({ blocksRemaining: 0, phase: PHASE.PLAYING });
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.won).toBe(true);
    });

    it("loses when no lives remain after LIFE_LOST", () => {
      const result = winCheck({ lives: 0, phase: PHASE.LIFE_LOST });
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.won).toBe(false);
    });

    it("does not finish with lives remaining and blocks left", () => {
      const result = winCheck({ lives: 2, blocksRemaining: 10, phase: PHASE.LIFE_LOST });
      expect(result.phase).toBe(PHASE.LIFE_LOST);
    });

    it("does nothing when not in relevant phase", () => {
      const result = winCheck({ lives: 0, phase: PHASE.COUNTDOWN });
      expect(result.phase).toBe(PHASE.COUNTDOWN);
    });
  });

  describe("serveBall", () => {
    serveBallTests(game, {});

    it("serves downward with direction 1", () => {
      expect(serveBall(createInitialState(), 1).ballVY).toBeGreaterThan(0);
    });

    it("serves upward with direction -1", () => {
      expect(serveBall(createInitialState(), -1).ballVY).toBeLessThan(0);
    });

    it("defaults to downward serve without direction", () => {
      expect(serveBall(createInitialState()).ballVY).toBeGreaterThan(0);
    });
  });

  describe("createBlockParticles", () => {
    particleBurstTests(createBlockParticles, 8);

    it("particles use provided color", () => {
      for (const p of createBlockParticles(100, 200, "#ff0066")) {
        expect(p.color).toBe("#ff0066");
      }
    });

    it("particles use default color when none provided", () => {
      for (const p of createBlockParticles(100, 200)) {
        expect(p.color).toBe("#ffaa00");
      }
    });
  });

  updateParticlesTests(game, 0.03);

  describe("stepTick", () => {
    stepTickMovesTest(game, {
      ballVX: 2,
      ballVY: 3,
      events: { wallBounced: false, paddleHit: false, blockHit: false, exitSide: null },
    });

    it("reports the side a lost ball went out by, and the serve goes back that way", () => {
      const keys = { left: false, right: false };
      const s = playingState(game, { ballX: 20, ballY: 3, ballVX: 0, ballVY: -3 });
      const { state, events } = stepTick(s, keys, keys);

      expect(events.exitSide).toBe("top");
      expect(state.phase).toBe(PHASE.LIFE_LOST);
      expect(state.lifeLost).toBe(false);
      expect(serveAfter(state, events.exitSide, () => 0.5).ballVY).toBeGreaterThan(0);
      expect(serveAfter(state, "bottom", () => 0.5).ballVY).toBeLessThan(0);
    });
  });
});
