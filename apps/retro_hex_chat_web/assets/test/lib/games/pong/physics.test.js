import { describe, it, expect } from "vitest";
import { PHASE } from "../../../../js/lib/games/pong/protocol.js";
import {
  CANVAS_W,
  CANVAS_H,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_W,
  PADDLE_SPEED,
  BALL_SIZE,
  WIN_SCORE,
  INITIAL_BALL_SPEED,
  MAX_BALL_SPEED,
  createInitialState,
  updatePaddle,
  updateBall,
  checkWallBounce,
  checkPaddleCollision,
  checkScore,
  checkWin,
  serveBall,
  createScoreParticles,
  updateParticles,
} from "../../../../js/lib/games/pong/physics.js";

describe("pong_physics", () => {
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

    it("creates state with paddles centered vertically", () => {
      const state = createInitialState();
      const expectedY = (CANVAS_H - PADDLE_H) / 2;
      expect(state.paddle1Y).toBe(expectedY);
      expect(state.paddle2Y).toBe(expectedY);
    });

    it("creates state with zero scores", () => {
      const state = createInitialState();
      expect(state.score1).toBe(0);
      expect(state.score2).toBe(0);
    });

    it("starts in WAITING phase", () => {
      const state = createInitialState();
      expect(state.phase).toBe(PHASE.WAITING);
    });

    it("starts with countdown at 3", () => {
      const state = createInitialState();
      expect(state.countdown).toBe(3);
    });
  });

  describe("updatePaddle", () => {
    it("moves paddle up", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { up: true, down: false });
      expect(result.paddle1Y).toBe(state.paddle1Y - PADDLE_SPEED);
    });

    it("moves paddle down", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { up: false, down: true });
      expect(result.paddle1Y).toBe(state.paddle1Y + PADDLE_SPEED);
    });

    it("does not move paddle with no input", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { up: false, down: false });
      expect(result.paddle1Y).toBe(state.paddle1Y);
    });

    it("cancels out with both up and down", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 1, { up: true, down: true });
      expect(result.paddle1Y).toBe(state.paddle1Y);
    });

    it("clamps paddle to top edge", () => {
      const state = { ...createInitialState(), paddle1Y: 2 };
      const result = updatePaddle(state, 1, { up: true, down: false });
      expect(result.paddle1Y).toBe(0);
    });

    it("clamps paddle to bottom edge", () => {
      const state = { ...createInitialState(), paddle1Y: CANVAS_H - PADDLE_H - 2 };
      const result = updatePaddle(state, 1, { up: false, down: true });
      expect(result.paddle1Y).toBe(CANVAS_H - PADDLE_H);
    });

    it("updates paddle 2 independently", () => {
      const state = createInitialState();
      const result = updatePaddle(state, 2, { up: true, down: false });
      expect(result.paddle2Y).toBe(state.paddle2Y - PADDLE_SPEED);
      expect(result.paddle1Y).toBe(state.paddle1Y);
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
    it("bounces ball off top wall", () => {
      const state = {
        ...createInitialState(),
        ballY: 2,
        ballVY: -5,
        phase: PHASE.PLAYING,
      };
      const result = checkWallBounce(state);
      expect(result.ballVY).toBeGreaterThan(0);
      expect(result.wallBounced).toBe(true);
    });

    it("bounces ball off bottom wall", () => {
      const state = {
        ...createInitialState(),
        ballY: CANVAS_H - 2,
        ballVY: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkWallBounce(state);
      expect(result.ballVY).toBeLessThan(0);
      expect(result.wallBounced).toBe(true);
    });

    it("does not bounce when ball is in middle", () => {
      const state = {
        ...createInitialState(),
        ballY: CANVAS_H / 2,
        ballVY: 3,
        phase: PHASE.PLAYING,
      };
      const result = checkWallBounce(state);
      expect(result.ballVY).toBe(3);
      expect(result.wallBounced).toBeFalsy();
    });

    it("does nothing when not playing", () => {
      const state = { ...createInitialState(), ballY: 0, ballVY: -5 };
      const result = checkWallBounce(state);
      expect(result.ballVY).toBe(-5);
    });
  });

  describe("checkPaddleCollision", () => {
    it("bounces off paddle 1 (left)", () => {
      const paddleCenter = (CANVAS_H - PADDLE_H) / 2 + PADDLE_H / 2;
      const state = {
        ...createInitialState(),
        ballX: PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2 - 1,
        ballY: paddleCenter,
        ballVX: -5,
        ballVY: 0,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.ballVX).toBeGreaterThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("bounces off paddle 2 (right)", () => {
      const paddleCenter = (CANVAS_H - PADDLE_H) / 2 + PADDLE_H / 2;
      const state = {
        ...createInitialState(),
        ballX: CANVAS_W - PADDLE_MARGIN - PADDLE_W - BALL_SIZE / 2 + 1,
        ballY: paddleCenter,
        ballVX: 5,
        ballVY: 0,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.ballVX).toBeLessThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("does not collide when ball moves away from paddle", () => {
      const paddleCenter = (CANVAS_H - PADDLE_H) / 2 + PADDLE_H / 2;
      const state = {
        ...createInitialState(),
        ballX: PADDLE_MARGIN + PADDLE_W + 5,
        ballY: paddleCenter,
        ballVX: 5,
        ballVY: 0,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.paddleHit).toBeFalsy();
    });

    it("increases ball speed on paddle hit", () => {
      const paddleCenter = (CANVAS_H - PADDLE_H) / 2 + PADDLE_H / 2;
      const state = {
        ...createInitialState(),
        ballX: PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2 - 1,
        ballY: paddleCenter,
        ballVX: -5,
        ballVY: 0,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.ballSpeed).toBeGreaterThan(5);
    });

    it("caps ball speed at MAX_BALL_SPEED", () => {
      const paddleCenter = (CANVAS_H - PADDLE_H) / 2 + PADDLE_H / 2;
      const state = {
        ...createInitialState(),
        ballX: PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2 - 1,
        ballY: paddleCenter,
        ballVX: -MAX_BALL_SPEED,
        ballVY: 0,
        ballSpeed: MAX_BALL_SPEED,
        phase: PHASE.PLAYING,
      };
      const result = checkPaddleCollision(state);
      expect(result.ballSpeed).toBe(MAX_BALL_SPEED);
    });

    it("creates steeper angle on edge hit", () => {
      const paddleTop = (CANVAS_H - PADDLE_H) / 2;
      const state = {
        ...createInitialState(),
        ballX: PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2 - 1,
        ballY: paddleTop,
        ballVX: -5,
        ballVY: 0,
        ballSpeed: 5,
        phase: PHASE.PLAYING,
      };
      const resultEdge = checkPaddleCollision(state);

      const stateCenter = {
        ...state,
        ballY: paddleTop + PADDLE_H / 2,
      };
      const resultCenter = checkPaddleCollision(stateCenter);

      expect(Math.abs(resultEdge.ballVY)).toBeGreaterThan(Math.abs(resultCenter.ballVY));
    });
  });

  describe("checkScore", () => {
    it("scores for player 2 when ball exits left", () => {
      const state = {
        ...createInitialState(),
        ballX: BALL_SIZE / 2 - 1,
        ballVX: -5,
        phase: PHASE.PLAYING,
      };
      const result = checkScore(state);
      expect(result.score2).toBe(1);
      expect(result.phase).toBe(PHASE.SCORED);
      expect(result.lastScorer).toBe(2);
    });

    it("scores for player 1 when ball exits right", () => {
      const state = {
        ...createInitialState(),
        ballX: CANVAS_W - BALL_SIZE / 2 + 1,
        ballVX: 5,
        phase: PHASE.PLAYING,
      };
      const result = checkScore(state);
      expect(result.score1).toBe(1);
      expect(result.phase).toBe(PHASE.SCORED);
      expect(result.lastScorer).toBe(1);
    });

    it("does not score when ball is in play area", () => {
      const state = {
        ...createInitialState(),
        ballX: CANVAS_W / 2,
        phase: PHASE.PLAYING,
      };
      const result = checkScore(state);
      expect(result.score1).toBe(0);
      expect(result.score2).toBe(0);
      expect(result.phase).toBe(PHASE.PLAYING);
    });

    it("does not score when not playing", () => {
      const state = {
        ...createInitialState(),
        ballX: -10,
      };
      const result = checkScore(state);
      expect(result.score2).toBe(0);
    });
  });

  describe("checkWin", () => {
    it("declares winner when score reaches WIN_SCORE with 2+ lead", () => {
      const state = {
        ...createInitialState(),
        score1: WIN_SCORE,
        score2: WIN_SCORE - 2,
        phase: PHASE.SCORED,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.winner).toBe(1);
    });

    it("player 2 wins", () => {
      const state = {
        ...createInitialState(),
        score1: 5,
        score2: WIN_SCORE,
        phase: PHASE.SCORED,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.winner).toBe(2);
    });

    it("does not win at WIN_SCORE if lead is only 1 (deuce)", () => {
      const state = {
        ...createInitialState(),
        score1: WIN_SCORE,
        score2: WIN_SCORE - 1,
        phase: PHASE.SCORED,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.SCORED);
      expect(result.winner).toBeUndefined();
    });

    it("wins in deuce scenario with 2 point lead", () => {
      const state = {
        ...createInitialState(),
        score1: 14,
        score2: 12,
        phase: PHASE.SCORED,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.winner).toBe(1);
    });

    it("does nothing when not in SCORED phase", () => {
      const state = {
        ...createInitialState(),
        score1: WIN_SCORE,
        score2: 0,
        phase: PHASE.PLAYING,
      };
      const result = checkWin(state);
      expect(result.phase).toBe(PHASE.PLAYING);
    });
  });

  describe("serveBall", () => {
    it("places ball at center", () => {
      const state = { ...createInitialState(), lastScorer: 1 };
      const result = serveBall(state);
      expect(result.ballX).toBe(CANVAS_W / 2);
      expect(result.ballY).toBe(CANVAS_H / 2);
    });

    it("serves toward opponent of last scorer", () => {
      const state = { ...createInitialState(), lastScorer: 1 };
      const result = serveBall(state);
      expect(result.ballVX).toBeGreaterThan(0);
    });

    it("serves left when player 2 scored last", () => {
      const state = { ...createInitialState(), lastScorer: 2 };
      const result = serveBall(state);
      expect(result.ballVX).toBeLessThan(0);
    });

    it("sets phase to PLAYING", () => {
      const state = { ...createInitialState(), lastScorer: 1, phase: PHASE.SERVING };
      const result = serveBall(state);
      expect(result.phase).toBe(PHASE.PLAYING);
    });

    it("resets ball speed to initial", () => {
      const state = { ...createInitialState(), lastScorer: 1, ballSpeed: 10 };
      const result = serveBall(state);
      expect(result.ballSpeed).toBe(INITIAL_BALL_SPEED);
    });

    it("has non-zero velocity", () => {
      const state = { ...createInitialState(), lastScorer: 1 };
      const result = serveBall(state);
      const speed = Math.sqrt(result.ballVX ** 2 + result.ballVY ** 2);
      expect(speed).toBeCloseTo(INITIAL_BALL_SPEED, 1);
    });
  });

  describe("createScoreParticles", () => {
    it("creates 10 particles", () => {
      const particles = createScoreParticles(320, 240);
      expect(particles).toHaveLength(10);
    });

    it("particles start at given position", () => {
      const particles = createScoreParticles(100, 200);
      for (const p of particles) {
        expect(p.x).toBe(100);
        expect(p.y).toBe(200);
      }
    });

    it("particles have velocity and life", () => {
      const particles = createScoreParticles(0, 0);
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
      const particles = [{ x: 0, y: 0, vx: 0, vy: 0, life: 0.02 }];
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
