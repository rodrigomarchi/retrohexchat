import { describe, it, expect } from "vitest";
import { PHASE, TOTAL_BLOCKS, BLOCK_ROWS } from "../../../../js/lib/games/breakout/protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  PADDLE_W,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_SPEED,
  BALL_SIZE,
  INITIAL_BALL_SPEED,
  INITIAL_LIVES,
  ROW_POINTS,
  createBlockGrid,
  createInitialState,
  updatePaddle,
  updateBall,
  checkWallBounce,
  checkPaddleCollision,
  checkBlockCollision,
  checkLifeLost,
  checkWin,
  serveBall,
  createBlockParticles,
  updateParticles,
} from "../../../../js/lib/games/breakout/physics.js";

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
    it("creates state with ball at center", () => {
      const state = createInitialState();
      expect(state.ballX).toBe(CANVAS_W / 2);
      expect(state.ballY).toBe(CANVAS_H / 2);
    });

    it("creates state with zero ball velocity", () => {
      const state = createInitialState();
      expect(state.ballVX).toBe(0);
      expect(state.ballVY).toBe(0);
    });

    it("creates state with paddles centered horizontally", () => {
      const state = createInitialState();
      const expectedX = (CANVAS_W - PADDLE_W) / 2;
      expect(state.paddle1X).toBe(expectedX);
      expect(state.paddle2X).toBe(expectedX);
    });

    it("starts with 3 lives", () => {
      const state = createInitialState();
      expect(state.lives).toBe(INITIAL_LIVES);
    });

    it("starts with zero score", () => {
      const state = createInitialState();
      expect(state.score).toBe(0);
    });

    it("starts in WAITING phase", () => {
      const state = createInitialState();
      expect(state.phase).toBe(PHASE.WAITING);
    });

    it("starts with all 50 blocks", () => {
      const state = createInitialState();
      expect(state.blocksRemaining).toBe(TOTAL_BLOCKS);
      expect(state.blocks).toHaveLength(TOTAL_BLOCKS);
    });

    it("starts with countdown at 3", () => {
      const state = createInitialState();
      expect(state.countdown).toBe(3);
    });
  });

  describe("updatePaddle", () => {
    it("moves paddle left", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { left: true, right: false });
      expect(result.paddle1X).toBe(state.paddle1X - PADDLE_SPEED);
    });

    it("moves paddle right", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { left: false, right: true });
      expect(result.paddle1X).toBe(state.paddle1X + PADDLE_SPEED);
    });

    it("does not move paddle with no input", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { left: false, right: false });
      expect(result.paddle1X).toBe(state.paddle1X);
    });

    it("cancels out with both left and right", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { left: true, right: true });
      expect(result.paddle1X).toBe(state.paddle1X);
    });

    it("clamps paddle to left edge", () => {
      const state = { ...createInitialState(), paddle1X: 2 };
      const result = updatePaddle(state, 1, { left: true, right: false });
      expect(result.paddle1X).toBe(0);
    });

    it("clamps paddle to right edge", () => {
      const state = { ...createInitialState(), paddle1X: CANVAS_W - PADDLE_W - 2 };
      const result = updatePaddle(state, 1, { left: false, right: true });
      expect(result.paddle1X).toBe(CANVAS_W - PADDLE_W);
    });

    it("updates paddle 2 independently", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 2, { left: true, right: false });
      expect(result.paddle2X).toBe(state.paddle2X - PADDLE_SPEED);
      expect(result.paddle1X).toBe(state.paddle1X);
    });
  });

  describe("updateBall", () => {
    it("moves ball by velocity when playing", () => {
      const state = {
        ...createInitialState(),
        ballVX: 3,
        ballVY: -2,
        phase: PHASE.PLAYING,
      };
      const result = updateBall(state);
      expect(result.ballX).toBe(state.ballX + 3);
      expect(result.ballY).toBe(state.ballY - 2);
    });

    it("does not move ball when not playing", () => {
      const state = { ...createInitialState(), ballVX: 3, ballVY: 2 };
      const result = updateBall(state);
      expect(result.ballX).toBe(state.ballX);
      expect(result.ballY).toBe(state.ballY);
    });
  });

  describe("checkWallBounce", () => {
    it("bounces ball off left wall", () => {
      const state = {
        ...createInitialState(),
        ballX: 2,
        ballVX: -5,
        phase: PHASE.PLAYING,
      };
      const result = checkWallBounce(state);
      expect(result.ballVX).toBeGreaterThan(0);
      expect(result.wallBounced).toBe(true);
    });

    it("bounces ball off right wall", () => {
      const state = {
        ...createInitialState(),
        ballX: CANVAS_W - 2,
        ballVX: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkWallBounce(state);
      expect(result.ballVX).toBeLessThan(0);
      expect(result.wallBounced).toBe(true);
    });

    it("does not bounce when ball is in middle", () => {
      const state = {
        ...createInitialState(),
        ballX: CANVAS_W / 2,
        ballVX: 3,
        phase: PHASE.PLAYING,
      };
      const result = checkWallBounce(state);
      expect(result.ballVX).toBe(3);
      expect(result.wallBounced).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      const state = { ...createInitialState(), ballX: 0, ballVX: -5 };
      const result = checkWallBounce(state);
      expect(result.ballVX).toBe(-5);
    });
  });

  describe("checkPaddleCollision", () => {
    it("bounces off bottom paddle (P1)", () => {
      const paddleCenterX = (CANVAS_W - PADDLE_W) / 2 + PADDLE_W / 2;
      const p1Top = CANVAS_H - PADDLE_MARGIN - PADDLE_H;
      const state = {
        ...createInitialState(),
        ballX: paddleCenterX,
        ballY: p1Top - BALL_SIZE / 2 + 1,
        ballVX: 0,
        ballVY: 5,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.ballVY).toBeLessThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("bounces off top paddle (P2)", () => {
      const paddleCenterX = (CANVAS_W - PADDLE_W) / 2 + PADDLE_W / 2;
      const p2Bottom = PADDLE_MARGIN + PADDLE_H;
      const state = {
        ...createInitialState(),
        ballX: paddleCenterX,
        ballY: p2Bottom + BALL_SIZE / 2 - 1,
        ballVX: 0,
        ballVY: -5,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.ballVY).toBeGreaterThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("does not collide when ball moves away from paddle", () => {
      const paddleCenterX = (CANVAS_W - PADDLE_W) / 2 + PADDLE_W / 2;
      const p1Top = CANVAS_H - PADDLE_MARGIN - PADDLE_H;
      const state = {
        ...createInitialState(),
        ballX: paddleCenterX,
        ballY: p1Top - 10,
        ballVX: 0,
        ballVY: -5,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.paddleHit).toBeFalsy();
    });

    it("creates steeper angle on edge hit", () => {
      const paddleLeft = (CANVAS_W - PADDLE_W) / 2;
      const p1Top = CANVAS_H - PADDLE_MARGIN - PADDLE_H;

      // Edge hit
      const stateEdge = {
        ...createInitialState(),
        ballX: paddleLeft,
        ballY: p1Top - BALL_SIZE / 2 + 1,
        ballVX: 0,
        ballVY: 5,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const resultEdge = checkPaddleCollision(stateEdge);

      // Center hit
      const stateCenter = {
        ...stateEdge,
        ballX: paddleLeft + PADDLE_W / 2,
      };
      const resultCenter = checkPaddleCollision(stateCenter);

      expect(Math.abs(resultEdge.ballVX)).toBeGreaterThan(Math.abs(resultCenter.ballVX));
    });
  });

  describe("checkBlockCollision", () => {
    it("destroys block on collision", () => {
      const state = createInitialState();
      const block = state.blocks[0];
      const collisionState = {
        ...state,
        ballX: block.x + block.w / 2,
        ballY: block.y + block.h / 2,
        ballVX: 0,
        ballVY: -4,
        phase: PHASE.PLAYING,
      };
      const result = checkBlockCollision(collisionState);
      expect(result.blocks[0].alive).toBe(false);
      expect(result.blocksRemaining).toBe(TOTAL_BLOCKS - 1);
      expect(result.blocksDestroyed).toBe(1);
    });

    it("adds score from destroyed block", () => {
      const state = createInitialState();
      const block = state.blocks[0]; // Row 0 = 50 pts
      const collisionState = {
        ...state,
        ballX: block.x + block.w / 2,
        ballY: block.y + block.h / 2,
        ballVX: 0,
        ballVY: -4,
        phase: PHASE.PLAYING,
      };
      const result = checkBlockCollision(collisionState);
      expect(result.score).toBe(ROW_POINTS[0]);
    });

    it("sets blockHit flag", () => {
      const state = createInitialState();
      const block = state.blocks[0];
      const collisionState = {
        ...state,
        ballX: block.x + block.w / 2,
        ballY: block.y + block.h / 2,
        ballVX: 0,
        ballVY: -4,
        phase: PHASE.PLAYING,
      };
      const result = checkBlockCollision(collisionState);
      expect(result.blockHit).toBe(true);
      expect(result.hitBlockRow).toBe(0);
    });

    it("reverses ball direction on collision", () => {
      const state = createInitialState();
      const block = state.blocks[0];
      const collisionState = {
        ...state,
        ballX: block.x + block.w / 2,
        ballY: block.y + block.h + BALL_SIZE / 2 - 1,
        ballVX: 0,
        ballVY: -4,
        phase: PHASE.PLAYING,
      };
      const result = checkBlockCollision(collisionState);
      expect(result.ballVY).toBe(4);
    });

    it("does not collide with dead blocks", () => {
      const state = createInitialState();
      state.blocks = state.blocks.map((b, i) => (i === 0 ? { ...b, alive: false } : b));
      const block = state.blocks[0];
      const collisionState = {
        ...state,
        ballX: block.x + block.w / 2,
        ballY: block.y + block.h / 2,
        ballVX: 0,
        ballVY: -4,
        phase: PHASE.PLAYING,
      };
      const result = checkBlockCollision(collisionState);
      expect(result.blockHit).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      const state = createInitialState();
      const block = state.blocks[0];
      const collisionState = {
        ...state,
        ballX: block.x + block.w / 2,
        ballY: block.y + block.h / 2,
        ballVX: 0,
        ballVY: -4,
      };
      const result = checkBlockCollision(collisionState);
      expect(result.blockHit).toBeFalsy();
    });
  });

  describe("checkLifeLost", () => {
    it("loses life when ball exits bottom", () => {
      const state = {
        ...createInitialState(),
        ballY: CANVAS_H - BALL_SIZE / 2 + 1,
        phase: PHASE.PLAYING,
      };
      const result = checkLifeLost(state);
      expect(result.lives).toBe(INITIAL_LIVES - 1);
      expect(result.phase).toBe(PHASE.LIFE_LOST);
      expect(result.lifeLost).toBe(true);
    });

    it("loses life when ball exits top", () => {
      const state = {
        ...createInitialState(),
        ballY: BALL_SIZE / 2 - 1,
        phase: PHASE.PLAYING,
      };
      const result = checkLifeLost(state);
      expect(result.lives).toBe(INITIAL_LIVES - 1);
      expect(result.phase).toBe(PHASE.LIFE_LOST);
    });

    it("does not lose life when ball is in play area", () => {
      const state = {
        ...createInitialState(),
        ballY: CANVAS_H / 2,
        phase: PHASE.PLAYING,
      };
      const result = checkLifeLost(state);
      expect(result.lives).toBe(INITIAL_LIVES);
      expect(result.lifeLost).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      const state = {
        ...createInitialState(),
        ballY: CANVAS_H + 10,
      };
      const result = checkLifeLost(state);
      expect(result.lives).toBe(INITIAL_LIVES);
    });
  });

  describe("checkWin", () => {
    it("wins when all blocks destroyed", () => {
      const state = {
        ...createInitialState(),
        blocksRemaining: 0,
        phase: PHASE.PLAYING,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.won).toBe(true);
    });

    it("loses when no lives remain after LIFE_LOST", () => {
      const state = {
        ...createInitialState(),
        lives: 0,
        phase: PHASE.LIFE_LOST,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.won).toBe(false);
    });

    it("does not finish with lives remaining and blocks left", () => {
      const state = {
        ...createInitialState(),
        lives: 2,
        blocksRemaining: 10,
        phase: PHASE.LIFE_LOST,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.LIFE_LOST);
    });

    it("does nothing when not in relevant phase", () => {
      const state = {
        ...createInitialState(),
        lives: 0,
        phase: PHASE.COUNTDOWN,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.COUNTDOWN);
    });
  });

  describe("serveBall", () => {
    it("places ball at center", () => {
      const state = createInitialState();
      const result = serveBall(state);
      expect(result.ballX).toBe(CANVAS_W / 2);
      expect(result.ballY).toBe(CANVAS_H / 2);
    });

    it("sets phase to PLAYING", () => {
      const state = { ...createInitialState(), phase: PHASE.SERVING };
      const result = serveBall(state);
      expect(result.phase).toBe(PHASE.PLAYING);
    });

    it("resets ball speed to initial", () => {
      const state = { ...createInitialState(), ballSpeed: 10 };
      const result = serveBall(state);
      expect(result.ballSpeed).toBe(INITIAL_BALL_SPEED);
    });

    it("has non-zero velocity", () => {
      const state = createInitialState();
      const result = serveBall(state);
      const speed = Math.sqrt(result.ballVX ** 2 + result.ballVY ** 2);
      expect(speed).toBeCloseTo(INITIAL_BALL_SPEED, 1);
    });
  });

  describe("createBlockParticles", () => {
    it("creates 8 particles", () => {
      const particles = createBlockParticles(320, 240);
      expect(particles).toHaveLength(8);
    });

    it("particles start at given position", () => {
      const particles = createBlockParticles(100, 200);
      for (const p of particles) {
        expect(p.x).toBe(100);
        expect(p.y).toBe(200);
      }
    });

    it("particles have velocity and life", () => {
      const particles = createBlockParticles(0, 0);
      for (const p of particles) {
        expect(typeof p.vx).toBe("number");
        expect(typeof p.vy).toBe("number");
        expect(p.life).toBe(1.0);
      }
    });
  });

  describe("updateParticles", () => {
    it("moves particles by velocity", () => {
      const particles = [{ x: 10, y: 20, vx: 2, vy: -1, life: 1.0 }];
      const result = updateParticles(particles);
      expect(result[0].x).toBeCloseTo(12);
      expect(result[0].y).toBeCloseTo(19);
    });

    it("decays life", () => {
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 1.0 }];
      const result = updateParticles(particles);
      expect(result[0].life).toBeLessThan(1.0);
    });

    it("removes dead particles", () => {
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 0.03 }];
      const result = updateParticles(particles);
      expect(result).toHaveLength(0);
    });

    it("applies drag to velocity", () => {
      const particles = [{ x: 0, y: 0, vx: 10, vy: 10, life: 1.0 }];
      const result = updateParticles(particles);
      expect(Math.abs(result[0].vx)).toBeLessThan(10);
      expect(Math.abs(result[0].vy)).toBeLessThan(10);
    });
  });
});
