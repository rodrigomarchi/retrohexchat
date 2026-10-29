import { describe, it, expect } from "vitest";
import { PHASE } from "../../../../js/lib/games/pong/protocol.js";
import * as physics from "../../../../js/lib/games/pong/physics.js";
import {
  CANVAS_W,
  CANVAS_H,
  PADDLE_H,
  PADDLE_MARGIN,
  PADDLE_W,
  BALL_SIZE,
  WIN_SCORE,
  MAX_BALL_SPEED,
  createInitialState,
  checkPaddleCollision,
  checkScore,
  checkWin,
  serveBall,
  createScoreParticles,
  stepTick,
} from "../../../../js/lib/games/pong/physics.js";
import {
  VERTICAL_AXIS,
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

const game = { physics, PHASE, axis: VERTICAL_AXIS };

/** Ball x just inside the left paddle's face. */
const LEFT_HIT_X = PADDLE_MARGIN + PADDLE_W + BALL_SIZE / 2 - 1;
/** Top edge of a paddle at its starting place. */
const PADDLE_TOP = (CANVAS_H - PADDLE_H) / 2;
/** Centre of a paddle at its starting place. */
const PADDLE_CENTER = PADDLE_TOP + PADDLE_H / 2;

/**
 * A playing ball level with the centre of the starting paddles, moving
 * horizontally at speed 5 toward the left paddle, with `overrides` applied.
 * @param {object} [overrides]
 */
function paddleBallState(overrides = {}) {
  return playingState(game, {
    ballX: LEFT_HIT_X,
    ballY: PADDLE_CENTER,
    ballVX: -5,
    ballVY: 0,
    ballSpeed: 5,
    ...overrides,
  });
}

/**
 * The win check on a fresh state with the given scores and phase.
 * @param {number} score1
 * @param {number} score2
 * @param {string} [phase]
 */
function winCheck(score1, score2, phase = PHASE.SCORED) {
  return checkWin({ ...createInitialState(), score1, score2, phase });
}

describe("pong_physics", () => {
  describe("createInitialState", () => {
    initialStateTests(game);

    it("creates state with zero scores", () => {
      const state = createInitialState();
      expect(state.score1).toBe(0);
      expect(state.score2).toBe(0);
    });
  });

  updatePaddleTests(game);
  updateBallTests(game);
  wallBounceTests(game);

  describe("checkPaddleCollision", () => {
    it("bounces off paddle 1 (left)", () => {
      const result = checkPaddleCollision(paddleBallState());
      expect(result.ballVX).toBeGreaterThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("bounces off paddle 2 (right)", () => {
      const result = checkPaddleCollision(
        paddleBallState({
          ballX: CANVAS_W - PADDLE_MARGIN - PADDLE_W - BALL_SIZE / 2 + 1,
          ballVX: 5,
        }),
      );
      expect(result.ballVX).toBeLessThan(0);
      expect(result.paddleHit).toBe(true);
    });

    it("does not collide when ball moves away from paddle", () => {
      const result = checkPaddleCollision(
        paddleBallState({ ballX: PADDLE_MARGIN + PADDLE_W + 5, ballVX: 5 }),
      );
      expect(result.paddleHit).toBeFalsy();
    });

    it("increases ball speed on paddle hit", () => {
      expect(checkPaddleCollision(paddleBallState()).ballSpeed).toBeGreaterThan(5);
    });

    it("caps ball speed at MAX_BALL_SPEED", () => {
      const state = paddleBallState({ ballVX: -MAX_BALL_SPEED, ballSpeed: MAX_BALL_SPEED });
      expect(checkPaddleCollision(state).ballSpeed).toBe(MAX_BALL_SPEED);
    });

    it("creates steeper angle on edge hit", () => {
      const resultEdge = checkPaddleCollision(paddleBallState({ ballY: PADDLE_TOP }));
      const resultCenter = checkPaddleCollision(paddleBallState({ ballY: PADDLE_CENTER }));

      expect(Math.abs(resultEdge.ballVY)).toBeGreaterThan(Math.abs(resultCenter.ballVY));
    });
  });

  describe("checkScore", () => {
    it("scores for player 2 when ball exits left", () => {
      const result = checkScore(playingState(game, { ballX: BALL_SIZE / 2 - 1, ballVX: -5 }));
      expect(result.score2).toBe(1);
      expect(result.phase).toBe(PHASE.SCORED);
      expect(result.lastScorer).toBe(2);
    });

    it("scores for player 1 when ball exits right", () => {
      const result = checkScore(
        playingState(game, { ballX: CANVAS_W - BALL_SIZE / 2 + 1, ballVX: 5 }),
      );
      expect(result.score1).toBe(1);
      expect(result.phase).toBe(PHASE.SCORED);
      expect(result.lastScorer).toBe(1);
    });

    it("does not score when ball is in play area", () => {
      const result = checkScore(playingState(game, { ballX: CANVAS_W / 2 }));
      expect(result.score1).toBe(0);
      expect(result.score2).toBe(0);
      expect(result.phase).toBe(PHASE.PLAYING);
    });

    it("does not score when not playing", () => {
      const result = checkScore({ ...createInitialState(), ballX: -10 });
      expect(result.score2).toBe(0);
    });
  });

  describe("checkWin", () => {
    it("declares winner when score reaches WIN_SCORE with 2+ lead", () => {
      const result = winCheck(WIN_SCORE, WIN_SCORE - 2);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.winner).toBe(1);
    });

    it("player 2 wins", () => {
      const result = winCheck(5, WIN_SCORE);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.winner).toBe(2);
    });

    it("does not win at WIN_SCORE if lead is only 1 (deuce)", () => {
      const result = winCheck(WIN_SCORE, WIN_SCORE - 1);
      expect(result.phase).toBe(PHASE.SCORED);
      expect(result.winner).toBeUndefined();
    });

    it("wins in deuce scenario with 2 point lead", () => {
      const result = winCheck(14, 12);
      expect(result.phase).toBe(PHASE.FINISHED);
      expect(result.winner).toBe(1);
    });

    it("does nothing when not in SCORED phase", () => {
      expect(winCheck(WIN_SCORE, 0, PHASE.PLAYING).phase).toBe(PHASE.PLAYING);
    });
  });

  describe("serveBall", () => {
    serveBallTests(game, { lastScorer: 1 });

    it("serves toward opponent of last scorer", () => {
      const result = serveBall({ ...createInitialState(), lastScorer: 1 });
      expect(result.ballVX).toBeGreaterThan(0);
    });

    it("serves left when player 2 scored last", () => {
      const result = serveBall({ ...createInitialState(), lastScorer: 2 });
      expect(result.ballVX).toBeLessThan(0);
    });
  });

  describe("createScoreParticles", () => {
    particleBurstTests(createScoreParticles, 10);
  });

  updateParticlesTests(game, 0.02);

  describe("stepTick", () => {
    stepTickMovesTest(game, {
      ballVX: 3,
      ballVY: 2,
      events: { wallBounced: false, paddleHit: false, scored: false },
    });

    it("reports a wall bounce and a point beside the state, with the flags down", () => {
      const keys = { up: false, down: false };
      const atWall = playingState(game, { ballY: 3, ballVX: 3, ballVY: -4 });
      const bounced = stepTick(atWall, keys, keys);
      expect(bounced.events.wallBounced).toBe(true);
      expect(bounced.state.wallBounced).toBe(false);

      const pastLeft = playingState(game, { ballX: 4, ballVX: -5, ballVY: 0 });
      const scored = stepTick({ ...pastLeft, paddle1Y: 400, ballY: 100 }, keys, keys);
      expect(scored.events.scored).toBe(true);
      expect(scored.state.score2).toBe(1);
      expect(scored.state.scored).toBe(false);
    });
  });
});
