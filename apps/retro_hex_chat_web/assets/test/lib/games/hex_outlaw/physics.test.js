import { describe, it, expect } from "vitest";
import {
  CANVAS_W,
  ARENA_TOP,
  ARENA_BOTTOM,
  ARENA_LEFT,
  ARENA_RIGHT,
  GUNSLINGER_W,
  GUNSLINGER_H,
  BULLET_SPEED_X,
  BULLET_RADIUS,
  SCORE_TO_WIN,
  ROUNDS_TO_WIN,
  HIT_PAUSE_DURATION,
  P1_SPAWN_X,
  P2_SPAWN_X,
  NML_P1_MAX_X,
  NML_P2_MIN_X,
  STAGE_H,
  createInitialState,
  moveGunslinger,
  fireBullet,
  tickBullets,
  checkBulletCollisions,
  tickObstacle,
  enterHitPause,
  tickHitPause,
  checkRoundEnd,
  advanceRound,
  resetForNewRound,
  getObstacleRect,
} from "../../../../js/lib/games/hex_outlaw/physics.js";
import { PHASE, GAME_MODE } from "../../../../js/lib/games/hex_outlaw/protocol.js";

describe("Hex Outlaw Physics", () => {
  describe("createInitialState", () => {
    it("creates state with correct spawn positions", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      expect(s.p1x).toBe(P1_SPAWN_X);
      expect(s.p2x).toBe(P2_SPAWN_X);
      expect(s.p1x).toBeLessThan(CANVAS_W / 2);
      expect(s.p2x).toBeGreaterThan(CANVAS_W / 2);
      expect(s.p1y).toBe(s.p2y);
    });

    it("starts in WAITING phase", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      expect(s.phase).toBe(PHASE.WAITING);
      expect(s.score1).toBe(0);
      expect(s.score2).toBe(0);
      expect(s.round).toBe(1);
    });

    it("defaults to QUICK_DRAW mode", () => {
      const s = createInitialState();
      expect(s.gameMode).toBe(GAME_MODE.QUICK_DRAW);
    });

    it("stores specified game mode", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      expect(s.gameMode).toBe(GAME_MODE.RICOCHET);
    });

    it("bullets are inactive initially", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      expect(s.b1active).toBe(false);
      expect(s.b2active).toBe(false);
    });
  });

  describe("moveGunslinger", () => {
    it("moves P1 down", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = moveGunslinger(s, 1, 1, 0);
      expect(s2.p1y).toBeGreaterThan(s.p1y);
    });

    it("moves P1 up", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = moveGunslinger(s, 1, -1, 0);
      expect(s2.p1y).toBeLessThan(s.p1y);
    });

    it("moves P2 vertically", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = moveGunslinger(s, 2, 1, 0);
      expect(s2.p2y).toBeGreaterThan(s.p2y);
    });

    it("clamps to arena top", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, p1y: ARENA_TOP + GUNSLINGER_H / 2 + 1 };
      const s2 = moveGunslinger(s, 1, -1, 0);
      expect(s2.p1y).toBeGreaterThanOrEqual(ARENA_TOP + GUNSLINGER_H / 2);
    });

    it("clamps to arena bottom", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, p1y: ARENA_BOTTOM - GUNSLINGER_H / 2 - 1 };
      const s2 = moveGunslinger(s, 1, 1, 0);
      expect(s2.p1y).toBeLessThanOrEqual(ARENA_BOTTOM - GUNSLINGER_H / 2);
    });

    it("does not move horizontally in non-NML modes", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = moveGunslinger(s, 1, 0, 1);
      expect(s2.p1x).toBe(s.p1x);
    });

    it("moves horizontally in No Man's Land", () => {
      const s = createInitialState(GAME_MODE.NO_MANS_LAND);
      const s2 = moveGunslinger(s, 1, 0, 1);
      expect(s2.p1x).toBeGreaterThan(s.p1x);
    });

    it("clamps P1 horizontal to NML zone", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = { ...s, p1x: NML_P1_MAX_X - 1 };
      const s2 = moveGunslinger(s, 1, 0, 1);
      expect(s2.p1x).toBeLessThanOrEqual(NML_P1_MAX_X);
    });

    it("clamps P2 horizontal to NML zone", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = { ...s, p2x: NML_P2_MIN_X + 1 };
      const s2 = moveGunslinger(s, 2, 0, -1);
      expect(s2.p2x).toBeGreaterThanOrEqual(NML_P2_MIN_X);
    });

    it("does not modify other player position", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = moveGunslinger(s, 1, 1, 0);
      expect(s2.p2y).toBe(s.p2y);
      expect(s2.p2x).toBe(s.p2x);
    });
  });

  describe("fireBullet", () => {
    it("creates bullet at P1 gun position traveling right", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = fireBullet(s, 1, false);
      expect(s2.b1active).toBe(true);
      expect(s2.b1vx).toBeGreaterThan(0);
      expect(s2.b1vy).toBe(0);
      expect(s2.b1x).toBeGreaterThan(s.p1x);
      expect(s2.b1y).toBe(s.p1y);
    });

    it("creates bullet at P2 gun position traveling left", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = fireBullet(s, 2, false);
      expect(s2.b2active).toBe(true);
      expect(s2.b2vx).toBeLessThan(0);
      expect(s2.b2vy).toBe(0);
      expect(s2.b2x).toBeLessThan(s.p2x);
    });

    it("does not fire if bullet already active", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = fireBullet(s, 1, false);
      expect(s.b1active).toBe(true);
      const s2 = fireBullet(s, 1, false);
      expect(s2).toBe(s); // Same reference — no change
    });

    it("sets shooting animation", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = fireBullet(s, 1, false);
      expect(s2.p1shooting).toBe(true);
      expect(s2.p1shootTimer).toBeGreaterThan(0);
    });

    it("fires at angle in ricochet mode", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      const s2 = fireBullet(s, 1, false);
      expect(s2.b1active).toBe(true);
      expect(s2.b1vx).toBeGreaterThan(0);
      expect(s2.b1vy).toBeGreaterThan(0); // Aiming down
    });

    it("fires upward in ricochet mode with aimUp", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      const s2 = fireBullet(s, 1, true);
      expect(s2.b1vy).toBeLessThan(0); // Aiming up
    });
  });

  describe("tickBullets", () => {
    it("moves active bullet forward", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = fireBullet(s, 1, false);
      const prevX = s.b1x;
      s = tickBullets(s);
      expect(s.b1x).toBeGreaterThan(prevX);
    });

    it("does not move inactive bullet", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = tickBullets(s);
      expect(s2.b1x).toBe(s.b1x);
    });

    it("deactivates bullet when exiting arena horizontally", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = {
        ...s,
        b1x: ARENA_RIGHT + 1,
        b1y: 200,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
      };
      s = tickBullets(s);
      expect(s.b1active).toBe(false);
    });

    it("ricochets off top wall", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      s = {
        ...s,
        b1x: 200,
        b1y: ARENA_TOP + BULLET_RADIUS + 1,
        b1vx: BULLET_SPEED_X,
        b1vy: -5,
        b1active: true,
        b1bounced: false,
      };
      s = tickBullets(s);
      expect(s.b1vy).toBeGreaterThan(0); // Bounced
      expect(s.b1bounced).toBe(true);
    });

    it("ricochets off bottom wall", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      s = {
        ...s,
        b1x: 200,
        b1y: ARENA_BOTTOM - BULLET_RADIUS - 1,
        b1vx: BULLET_SPEED_X,
        b1vy: 5,
        b1active: true,
        b1bounced: false,
      };
      s = tickBullets(s);
      expect(s.b1vy).toBeLessThan(0); // Bounced
      expect(s.b1bounced).toBe(true);
    });

    it("does not bounce twice (max 1 ricochet)", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      s = {
        ...s,
        b1x: 200,
        b1y: ARENA_TOP + BULLET_RADIUS + 1,
        b1vx: BULLET_SPEED_X,
        b1vy: -5,
        b1active: true,
        b1bounced: true, // Already bounced once
      };
      s = tickBullets(s);
      // Should not bounce again — vy stays negative
      expect(s.b1vy).toBe(-5);
    });

    it("ticks shoot animation timers", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = fireBullet(s, 1, false);
      expect(s.p1shooting).toBe(true);
      const initTimer = s.p1shootTimer;
      s = tickBullets(s);
      expect(s.p1shootTimer).toBeLessThan(initTimer);
    });
  });

  describe("getObstacleRect", () => {
    it("returns cactus rect for QUICK_DRAW", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const rect = getObstacleRect(s);
      expect(rect).not.toBeNull();
      expect(rect.x).toBeLessThan(CANVAS_W / 2);
      expect(rect.x + rect.w).toBeGreaterThan(CANVAS_W / 2);
    });

    it("returns wall rect for RICOCHET", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      const rect = getObstacleRect(s);
      expect(rect).not.toBeNull();
      expect(rect.h).toBeGreaterThan(getObstacleRect(createInitialState(GAME_MODE.QUICK_DRAW)).h);
    });

    it("returns stagecoach rect for STAGECOACH", () => {
      const s = createInitialState(GAME_MODE.STAGECOACH);
      const rect = getObstacleRect(s);
      expect(rect).not.toBeNull();
    });

    it("returns null for NO_MANS_LAND", () => {
      const s = createInitialState(GAME_MODE.NO_MANS_LAND);
      expect(getObstacleRect(s)).toBeNull();
    });
  });

  describe("checkBulletCollisions", () => {
    it("scores when bullet hits opponent", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      // Place bullet right on top of P2
      s = {
        ...s,
        b1x: s.p2x,
        b1y: s.p2y,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
      };
      const { state, p2Hit } = checkBulletCollisions(s);
      expect(p2Hit).toBe(true);
      expect(state.score1).toBe(1);
      expect(state.b1active).toBe(false);
      expect(state.lastHitPlayer).toBe(1);
    });

    it("P2 bullet scores when hitting P1", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = {
        ...s,
        b2x: s.p1x,
        b2y: s.p1y,
        b2vx: -BULLET_SPEED_X,
        b2vy: 0,
        b2active: true,
        b2bounced: false,
      };
      const { state, p1Hit } = checkBulletCollisions(s);
      expect(p1Hit).toBe(true);
      expect(state.score2).toBe(1);
      expect(state.b2active).toBe(false);
      expect(state.lastHitPlayer).toBe(2);
    });

    it("bullet blocked by obstacle", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      const obsRect = getObstacleRect(s);
      s = {
        ...s,
        b1x: obsRect.x + obsRect.w / 2,
        b1y: obsRect.y + obsRect.h / 2,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
      };
      const { state, obsHit } = checkBulletCollisions(s);
      expect(obsHit).toBe(true);
      expect(state.b1active).toBe(false);
      expect(state.score1).toBe(0); // No score for hitting obstacle
    });

    it("no collision when bullet misses", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = {
        ...s,
        b1x: CANVAS_W / 2,
        b1y: ARENA_TOP + 10,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
      };
      const { state, p2Hit, obsHit } = checkBulletCollisions(s);
      expect(p2Hit).toBe(false);
      expect(obsHit).toBe(false);
      expect(state.b1active).toBe(true);
    });
  });

  describe("tickObstacle", () => {
    it("does nothing for non-STAGECOACH modes", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = tickObstacle(s);
      expect(s2.obsY).toBe(s.obsY);
    });

    it("moves stagecoach vertically", () => {
      const s = createInitialState(GAME_MODE.STAGECOACH);
      const s2 = tickObstacle(s);
      expect(s2.obsY).not.toBe(s.obsY);
    });

    it("bounces stagecoach at bottom", () => {
      let s = createInitialState(GAME_MODE.STAGECOACH);
      s = { ...s, obsY: ARENA_BOTTOM - 1, obsDir: 1 };
      const s2 = tickObstacle(s);
      expect(s2.obsDir).toBe(-1); // Reversed direction
    });

    it("bounces stagecoach at top", () => {
      let s = createInitialState(GAME_MODE.STAGECOACH);
      s = { ...s, obsY: ARENA_TOP + 1, obsDir: -1 };
      const s2 = tickObstacle(s);
      expect(s2.obsDir).toBe(1); // Reversed direction
    });
  });

  describe("enterHitPause", () => {
    it("sets phase and timer", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, phase: PHASE.PLAYING };
      s = enterHitPause(s);
      expect(s.phase).toBe(PHASE.HIT_PAUSE);
      expect(s.hitPauseTimer).toBe(HIT_PAUSE_DURATION);
    });

    it("deactivates bullets", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, b1active: true, b2active: true };
      s = enterHitPause(s);
      expect(s.b1active).toBe(false);
      expect(s.b2active).toBe(false);
    });
  });

  describe("tickHitPause", () => {
    it("decrements timer", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, phase: PHASE.HIT_PAUSE, hitPauseTimer: 10 };
      const s2 = tickHitPause(s);
      expect(s2.hitPauseTimer).toBe(9);
    });

    it("resets positions when timer expires", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, phase: PHASE.HIT_PAUSE, hitPauseTimer: 1, p1y: 100, p2y: 400 };
      const s2 = tickHitPause(s);
      expect(s2.phase).toBe(PHASE.PLAYING);
      expect(s2.p1x).toBe(P1_SPAWN_X);
      expect(s2.p2x).toBe(P2_SPAWN_X);
      expect(s2.hitPauseTimer).toBe(0);
    });

    it("does nothing if not in HIT_PAUSE phase", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = tickHitPause(s);
      expect(s2).toBe(s);
    });
  });

  describe("checkRoundEnd", () => {
    it("P1 wins when reaching SCORE_TO_WIN", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, score1: SCORE_TO_WIN };
      const { ended, roundWinner } = checkRoundEnd(s);
      expect(ended).toBe(true);
      expect(roundWinner).toBe(1);
    });

    it("P2 wins when reaching SCORE_TO_WIN", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, score2: SCORE_TO_WIN };
      const { ended, roundWinner } = checkRoundEnd(s);
      expect(ended).toBe(true);
      expect(roundWinner).toBe(2);
    });

    it("not ended when scores below target", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, score1: 5, score2: 8 };
      const { ended } = checkRoundEnd(s);
      expect(ended).toBe(false);
    });
  });

  describe("advanceRound", () => {
    it("increments round wins", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = advanceRound(s, 1);
      expect(s.roundWins1).toBe(1);
      expect(s.roundWins2).toBe(0);
      expect(s.phase).toBe(PHASE.ROUND_OVER);
    });

    it("sets MATCH_OVER when enough round wins", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, roundWins1: ROUNDS_TO_WIN - 1 };
      s = advanceRound(s, 1);
      expect(s.phase).toBe(PHASE.MATCH_OVER);
      expect(s.roundWins1).toBe(ROUNDS_TO_WIN);
    });

    it("P2 can win match", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, roundWins2: ROUNDS_TO_WIN - 1 };
      s = advanceRound(s, 2);
      expect(s.phase).toBe(PHASE.MATCH_OVER);
      expect(s.roundWins2).toBe(ROUNDS_TO_WIN);
    });
  });

  describe("resetForNewRound", () => {
    it("resets positions and scores", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, score1: 10, score2: 5, p1y: 100, p2y: 400, round: 1, roundWins1: 1 };
      const s2 = resetForNewRound(s);
      expect(s2.score1).toBe(0);
      expect(s2.score2).toBe(0);
      expect(s2.p1x).toBe(P1_SPAWN_X);
      expect(s2.p2x).toBe(P2_SPAWN_X);
      expect(s2.round).toBe(2);
      expect(s2.roundWins1).toBe(1); // Preserved
    });

    it("deactivates bullets", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, b1active: true, b2active: true };
      const s2 = resetForNewRound(s);
      expect(s2.b1active).toBe(false);
      expect(s2.b2active).toBe(false);
    });

    it("resets to WAITING phase", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, phase: PHASE.ROUND_OVER };
      const s2 = resetForNewRound(s);
      expect(s2.phase).toBe(PHASE.WAITING);
    });

    it("preserves gameMode and roundWins2", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      s = { ...s, roundWins2: 1, round: 2 };
      const s2 = resetForNewRound(s);
      expect(s2.gameMode).toBe(GAME_MODE.RICOCHET);
      expect(s2.roundWins2).toBe(1);
      expect(s2.round).toBe(3);
    });
  });

  // ====== EDGE CASES ======

  describe("edge cases: createInitialState", () => {
    it("creates valid state for all 4 game modes", () => {
      for (const mode of [
        GAME_MODE.QUICK_DRAW,
        GAME_MODE.RICOCHET,
        GAME_MODE.STAGECOACH,
        GAME_MODE.NO_MANS_LAND,
      ]) {
        const s = createInitialState(mode);
        expect(s.gameMode).toBe(mode);
        expect(s.phase).toBe(PHASE.WAITING);
        expect(s.b1active).toBe(false);
        expect(s.b2active).toBe(false);
      }
    });
  });

  describe("edge cases: fireBullet", () => {
    it("P2 fires at angle in ricochet mode (traveling left)", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      const s2 = fireBullet(s, 2, false);
      expect(s2.b2active).toBe(true);
      expect(s2.b2vx).toBeLessThan(0); // Traveling left
      expect(s2.b2vy).toBeGreaterThan(0); // Aiming down (default)
    });

    it("P2 fires upward in ricochet mode", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      const s2 = fireBullet(s, 2, true);
      expect(s2.b2vx).toBeLessThan(0);
      expect(s2.b2vy).toBeLessThan(0); // Aiming up
    });

    it("aimUp has no effect in non-ricochet modes", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const s2 = fireBullet(s, 1, true);
      expect(s2.b1vy).toBe(0); // Still straight horizontal
    });

    it("aimUp has no effect in stagecoach mode", () => {
      const s = createInitialState(GAME_MODE.STAGECOACH);
      const s2 = fireBullet(s, 1, true);
      expect(s2.b1vy).toBe(0);
    });
  });

  describe("edge cases: tickBullets", () => {
    it("bounced bullet deactivates when reaching opposite wall", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      // Bullet already bounced, now heading toward bottom wall
      s = {
        ...s,
        b1x: 200,
        b1y: ARENA_BOTTOM - BULLET_RADIUS,
        b1vx: BULLET_SPEED_X,
        b1vy: 5,
        b1active: true,
        b1bounced: true,
      };
      s = tickBullets(s);
      // Should deactivate because bounced && out of vertical bounds
      expect(s.b1active).toBe(false);
    });

    it("exact boundary ricochet triggers bounce", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      // Place bullet so y + vy lands exactly at ARENA_TOP + BULLET_RADIUS
      s = {
        ...s,
        b1x: 200,
        b1y: ARENA_TOP + BULLET_RADIUS + 5,
        b1vx: BULLET_SPEED_X,
        b1vy: -5,
        b1active: true,
        b1bounced: false,
      };
      s = tickBullets(s);
      // y = (ARENA_TOP + BR + 5) + (-5) = ARENA_TOP + BR, condition: y - BR <= ARENA_TOP → true
      expect(s.b1bounced).toBe(true);
      expect(s.b1vy).toBeGreaterThan(0);
    });

    it("bullet stays active after bounce (not immediately deactivated)", () => {
      let s = createInitialState(GAME_MODE.RICOCHET);
      s = {
        ...s,
        b1x: 200,
        b1y: ARENA_TOP + BULLET_RADIUS + 3,
        b1vx: BULLET_SPEED_X,
        b1vy: -5,
        b1active: true,
        b1bounced: false,
      };
      s = tickBullets(s);
      expect(s.b1active).toBe(true);
      expect(s.b1bounced).toBe(true);
    });

    it("bullet exits left side deactivates", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = {
        ...s,
        b2x: ARENA_LEFT - 1,
        b2y: 200,
        b2vx: -BULLET_SPEED_X,
        b2vy: 0,
        b2active: true,
        b2bounced: false,
      };
      s = tickBullets(s);
      expect(s.b2active).toBe(false);
    });
  });

  describe("edge cases: checkBulletCollisions", () => {
    it("simultaneous hits score for both players", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = {
        ...s,
        b1x: s.p2x,
        b1y: s.p2y,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
        b2x: s.p1x,
        b2y: s.p1y,
        b2vx: -BULLET_SPEED_X,
        b2vy: 0,
        b2active: true,
        b2bounced: false,
      };
      const { state, p1Hit, p2Hit } = checkBulletCollisions(s);
      expect(p1Hit).toBe(true);
      expect(p2Hit).toBe(true);
      expect(state.score1).toBe(1);
      expect(state.score2).toBe(1);
    });

    it("obstacle blocks bullet even when player is behind it", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      const obsRect = getObstacleRect(s);
      // Move P2 to be directly behind the obstacle
      s = {
        ...s,
        p2x: obsRect.x + obsRect.w + GUNSLINGER_W / 2,
        p2y: obsRect.y + obsRect.h / 2,
        b1x: obsRect.x + obsRect.w / 2,
        b1y: obsRect.y + obsRect.h / 2,
        b1vx: BULLET_SPEED_X,
        b1vy: 0,
        b1active: true,
        b1bounced: false,
      };
      const { state, p2Hit, obsHit } = checkBulletCollisions(s);
      expect(obsHit).toBe(true);
      expect(p2Hit).toBe(false);
      expect(state.score1).toBe(0); // Obstacle absorbed the bullet
    });

    it("inactive bullet does not collide", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = {
        ...s,
        b1x: s.p2x,
        b1y: s.p2y,
        b1active: false,
      };
      const { p2Hit } = checkBulletCollisions(s);
      expect(p2Hit).toBe(false);
    });
  });

  describe("edge cases: tickObstacle", () => {
    it("stagecoach oscillates without drift over many frames", () => {
      let s = createInitialState(GAME_MODE.STAGECOACH);
      const startY = s.obsY;
      // Tick 1000 frames
      for (let i = 0; i < 1000; i++) {
        s = tickObstacle(s);
      }
      const minY = ARENA_TOP + STAGE_H / 2;
      const maxY = ARENA_BOTTOM - STAGE_H / 2;
      expect(s.obsY).toBeGreaterThanOrEqual(minY);
      expect(s.obsY).toBeLessThanOrEqual(maxY);
      // Should have oscillated back close to start (not drift)
      expect(Math.abs(s.obsY - startY)).toBeLessThan(ARENA_BOTTOM - ARENA_TOP);
    });

    it("does nothing for RICOCHET mode", () => {
      const s = createInitialState(GAME_MODE.RICOCHET);
      const s2 = tickObstacle(s);
      expect(s2.obsY).toBe(s.obsY);
    });
  });

  describe("edge cases: moveGunslinger", () => {
    it("already at top clamp stays at clamp", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, p1y: ARENA_TOP + GUNSLINGER_H / 2 };
      const s2 = moveGunslinger(s, 1, -1, 0);
      expect(s2.p1y).toBe(ARENA_TOP + GUNSLINGER_H / 2);
    });

    it("already at bottom clamp stays at clamp", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = { ...s, p1y: ARENA_BOTTOM - GUNSLINGER_H / 2 };
      const s2 = moveGunslinger(s, 1, 1, 0);
      expect(s2.p1y).toBe(ARENA_BOTTOM - GUNSLINGER_H / 2);
    });

    it("P1 NML left clamp at arena edge", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = { ...s, p1x: ARENA_LEFT + GUNSLINGER_W / 2 + 1 };
      const s2 = moveGunslinger(s, 1, 0, -1);
      expect(s2.p1x).toBeGreaterThanOrEqual(ARENA_LEFT + GUNSLINGER_W / 2);
    });

    it("P2 NML right clamp at arena edge", () => {
      let s = createInitialState(GAME_MODE.NO_MANS_LAND);
      s = { ...s, p2x: ARENA_RIGHT - GUNSLINGER_W / 2 - 1 };
      const s2 = moveGunslinger(s, 2, 0, 1);
      expect(s2.p2x).toBeLessThanOrEqual(ARENA_RIGHT - GUNSLINGER_W / 2);
    });
  });

  describe("edge cases: state immutability", () => {
    it("fireBullet does not mutate input state", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const original = { ...s };
      fireBullet(s, 1, false);
      expect(s.b1active).toBe(original.b1active);
      expect(s.p1shooting).toBe(original.p1shooting);
    });

    it("moveGunslinger does not mutate input state", () => {
      const s = createInitialState(GAME_MODE.QUICK_DRAW);
      const originalY = s.p1y;
      moveGunslinger(s, 1, 1, 0);
      expect(s.p1y).toBe(originalY);
    });

    it("tickBullets does not mutate input state", () => {
      let s = createInitialState(GAME_MODE.QUICK_DRAW);
      s = fireBullet(s, 1, false);
      const prevX = s.b1x;
      tickBullets(s);
      expect(s.b1x).toBe(prevX);
    });
  });
});
