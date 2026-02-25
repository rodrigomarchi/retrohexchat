import { describe, it, expect } from "vitest";
import {
  PHASE,
  GAME_MODE,
  ANNOUNCEMENT,
  OUT_TYPE,
} from "../../../../js/lib/games/hex_tennis/protocol.js";
import {
  CANVAS_W,
  COURT_LEFT,
  COURT_RIGHT,
  COURT_TOP,
  COURT_BOTTOM,
  NET_Y,
  NET_HEIGHT_FACTOR,
  PLAYER_SPEED,
  HIT_ZONE_W,
  BALL_MAX_SPEED,
  BALL_MIN_SPEED,
  BALL_DECELERATION,
  SERVE_SPEED,
  SERVE_TIMEOUT_FRAMES,
  SERVICE_LINE_TOP,
  SERVICE_LINE_BOTTOM,
  CENTER_LINE_X,
  createInitialState,
  updatePlayer,
  updateBall,
  checkHitZone,
  checkNetCollision,
  checkOutOfBounds,
  performServe,
  checkServeLanding,
  checkSetWin,
  advanceScore,
  shouldChangeover,
  resetForNextPoint,
  clearEventFlags,
} from "../../../../js/lib/games/hex_tennis/physics.js";

describe("tennis_physics", () => {
  describe("createInitialState", () => {
    it("places P1 near bottom baseline, P2 near top baseline", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.p1y).toBeGreaterThan(NET_Y);
      expect(s.p2y).toBeLessThan(NET_Y);
      expect(s.p1x).toBeCloseTo(CANVAS_W / 2, 0);
      expect(s.p2x).toBeCloseTo(CANVAS_W / 2, 0);
    });

    it("ball at center with zero velocity", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.ball.vx).toBe(0);
      expect(s.ball.vy).toBe(0);
      expect(s.ball.speed).toBe(0);
    });

    it("starts in WAITING phase", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.phase).toBe(PHASE.WAITING);
    });

    it("scores start at 0/0, 0-0 games", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.p1Points).toBe(0);
      expect(s.p2Points).toBe(0);
      expect(s.p1Games).toBe(0);
      expect(s.p2Games).toBe(0);
    });

    it("server starts as player 1", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.server).toBe(1);
    });

    it("gameMode matches input parameter", () => {
      expect(createInitialState(GAME_MODE.CLASSIC).gameMode).toBe(GAME_MODE.CLASSIC);
      expect(createInitialState(GAME_MODE.QUICK).gameMode).toBe(GAME_MODE.QUICK);
      expect(createInitialState(GAME_MODE.SUDDEN_DEATH).gameMode).toBe(GAME_MODE.SUDDEN_DEATH);
    });
  });

  describe("updatePlayer", () => {
    it("moves player down at PLAYER_SPEED", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: false, down: true, left: false, right: false });
      expect(r.p1y).toBe(s.p1y + PLAYER_SPEED);
    });

    it("moves player up at PLAYER_SPEED", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: true, down: false, left: false, right: false });
      expect(r.p1y).toBe(s.p1y - PLAYER_SPEED);
    });

    it("moves player left at PLAYER_SPEED", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: false, down: false, left: true, right: false });
      expect(r.p1x).toBe(s.p1x - PLAYER_SPEED);
    });

    it("moves player right at PLAYER_SPEED", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: false, down: false, left: false, right: true });
      expect(r.p1x).toBe(s.p1x + PLAYER_SPEED);
    });

    it("no movement with no input", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: false, down: false, left: false, right: false });
      expect(r.p1x).toBe(s.p1x);
      expect(r.p1y).toBe(s.p1y);
    });

    it("cancels opposing inputs (up+down)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: true, down: true, left: false, right: false });
      expect(r.p1y).toBe(s.p1y);
    });

    it("cancels opposing inputs (left+right)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 1, { up: false, down: false, left: true, right: true });
      expect(r.p1x).toBe(s.p1x);
    });

    it("clamps P1 to bottom half (cannot cross net)", () => {
      const s = { ...createInitialState(GAME_MODE.CLASSIC), p1y: NET_Y + 15 };
      const r = updatePlayer(s, 1, { up: true, down: false, left: false, right: false });
      expect(r.p1y).toBeGreaterThanOrEqual(NET_Y + 10);
    });

    it("clamps P2 to top half (cannot cross net)", () => {
      const s = { ...createInitialState(GAME_MODE.CLASSIC), p2y: NET_Y - 15 };
      const r = updatePlayer(s, 2, { up: false, down: true, left: false, right: false });
      expect(r.p2y).toBeLessThanOrEqual(NET_Y - 10);
    });

    it("clamps to left court boundary", () => {
      const s = { ...createInitialState(GAME_MODE.CLASSIC), p1x: COURT_LEFT + 5 };
      const r = updatePlayer(s, 1, { up: false, down: false, left: true, right: false });
      expect(r.p1x).toBeGreaterThanOrEqual(COURT_LEFT + 12);
    });

    it("clamps to right court boundary", () => {
      const s = { ...createInitialState(GAME_MODE.CLASSIC), p1x: COURT_RIGHT - 5 };
      const r = updatePlayer(s, 1, { up: false, down: false, left: false, right: true });
      expect(r.p1x).toBeLessThanOrEqual(COURT_RIGHT - 12);
    });

    it("updates P2 independently", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const r = updatePlayer(s, 2, { up: true, down: false, left: false, right: false });
      expect(r.p2y).toBe(s.p2y - PLAYER_SPEED);
      expect(r.p1y).toBe(s.p1y);
    });
  });

  describe("updateBall", () => {
    it("moves ball by velocity", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = { ...s.ball, x: 320, y: 300, vx: 3, vy: -2, speed: 5, height: 0.5, heightVel: 0 };
      s.phase = PHASE.RALLY;
      const r = updateBall(s);
      expect(r.ball.x).toBe(323);
      expect(r.ball.y).toBe(298);
    });

    it("decelerates ball each frame", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = { ...s.ball, x: 320, y: 300, vx: 3, vy: -4, speed: 5, height: 0.5, heightVel: 0 };
      s.phase = PHASE.RALLY;
      const r = updateBall(s);
      expect(r.ball.speed).toBeLessThan(5);
      expect(r.ball.speed).toBeCloseTo(5 - BALL_DECELERATION, 5);
    });

    it("does not go below minimum speed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = {
        ...s.ball,
        x: 320,
        y: 300,
        vx: 1,
        vy: -1,
        speed: BALL_MIN_SPEED,
        height: 0.5,
        heightVel: 0,
      };
      s.phase = PHASE.RALLY;
      const r = updateBall(s);
      expect(r.ball.speed).toBeGreaterThanOrEqual(BALL_MIN_SPEED);
    });

    it("simulates height arc (parabolic)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = { ...s.ball, x: 320, y: 300, vx: 0, vy: -3, speed: 3, height: 0.3, heightVel: 0.05 };
      s.phase = PHASE.RALLY;
      const r = updateBall(s);
      // Height increases with positive heightVel
      expect(r.ball.height).toBeGreaterThan(0.3);
    });

    it("height floors at 0", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = {
        ...s.ball,
        x: 320,
        y: 300,
        vx: 0,
        vy: -3,
        speed: 3,
        height: 0.01,
        heightVel: -0.05,
      };
      s.phase = PHASE.RALLY;
      const r = updateBall(s);
      expect(r.ball.height).toBeGreaterThanOrEqual(0);
    });

    it("does not move ball during SERVING phase", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = { ...s.ball, x: 320, y: 300, vx: 3, vy: -2, speed: 5, height: 0, heightVel: 0 };
      s.phase = PHASE.SERVING;
      const r = updateBall(s);
      expect(r.ball.x).toBe(320);
      expect(r.ball.y).toBe(300);
    });
  });

  describe("checkHitZone — THE core mechanic", () => {
    function makeRallyState(ballX, ballY, ballVY, player, playerX, playerY) {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: ballX,
        y: ballY,
        vx: 0,
        vy: ballVY,
        speed: Math.abs(ballVY),
        height: 0.1,
        heightVel: 0,
      };
      s.lastHitter = player === 1 ? 2 : 1; // ball coming FROM the other player
      if (player === 1) {
        s.p1x = playerX;
        s.p1y = playerY;
      } else {
        s.p2x = playerX;
        s.p2y = playerY;
      }
      return s;
    }

    it("ball in center of zone → straight return (vx ≈ 0)", () => {
      // P1 at bottom, ball coming down (positive vy), hitting center
      const s = makeRallyState(320, 400, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.ball.vy).toBeLessThan(0); // P1 hits upward
      expect(Math.abs(r.ball.vx)).toBeLessThan(1); // nearly straight
      expect(r.hitEvent).toBe(true);
    });

    it("ball at left edge of zone → cross-court angle (negative vx)", () => {
      // Ball hits LEFT side of P1's zone → cross-court to the left
      const s = makeRallyState(320 - HIT_ZONE_W / 2 + 1, 400, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.ball.vy).toBeLessThan(0);
      expect(r.ball.vx).toBeLessThan(-0.5);
    });

    it("ball at right edge of zone → cross-court angle (positive vx)", () => {
      // Ball hits RIGHT side of P1's zone → cross-court to the right
      const s = makeRallyState(320 + HIT_ZONE_W / 2 - 1, 400, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.ball.vy).toBeLessThan(0);
      expect(r.ball.vx).toBeGreaterThan(0.5);
    });

    it("does NOT hit if ball is outside hit zone", () => {
      const s = makeRallyState(320, 350, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.hitEvent).toBeFalsy();
    });

    it("does NOT hit if ball is moving AWAY from player", () => {
      // Ball going UP (vy < 0), away from P1 at bottom
      const s = makeRallyState(320, 400, -4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.hitEvent).toBeFalsy();
    });

    it("increments rallyCount on hit", () => {
      const s = makeRallyState(320, 400, 4, 1, 320, 400);
      s.rallyCount = 3;
      const r = checkHitZone(s, 1);
      expect(r.rallyCount).toBe(4);
    });

    it("sets lastHitter to correct player", () => {
      const s = makeRallyState(320, 400, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.lastHitter).toBe(1);
    });

    it("sets hitEvent flag to true", () => {
      const s = makeRallyState(320, 400, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.hitEvent).toBe(true);
    });

    it("assigns ball height > 0 after hit (for net clearance)", () => {
      const s = makeRallyState(320, 400, 4, 1, 320, 400);
      s.ball.height = 0;
      const r = checkHitZone(s, 1);
      expect(r.ball.height).toBeGreaterThan(0);
    });

    it("P1 hits ball upward (negative vy)", () => {
      const s = makeRallyState(320, 400, 4, 1, 320, 400);
      const r = checkHitZone(s, 1);
      expect(r.ball.vy).toBeLessThan(0);
    });

    it("P2 hits ball downward (positive vy)", () => {
      const s = makeRallyState(320, 70, -4, 2, 320, 70);
      const r = checkHitZone(s, 2);
      expect(r.ball.vy).toBeGreaterThan(0);
    });

    it("return speed is capped at BALL_MAX_SPEED", () => {
      const s = makeRallyState(320, 400, BALL_MAX_SPEED + 5, 1, 320, 400);
      s.ball.speed = BALL_MAX_SPEED + 5;
      const r = checkHitZone(s, 1);
      expect(r.ball.speed).toBeLessThanOrEqual(BALL_MAX_SPEED);
    });
  });

  describe("checkNetCollision", () => {
    it("ball crossing net with low height → net fault", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: NET_Y, vx: 0, vy: -3, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 1;
      const r = checkNetCollision(s);
      expect(r.netFault).toBe(true);
      expect(r.pointWinner).toBe(2); // hitter loses
    });

    it("ball crossing net with sufficient height → passes cleanly", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: 320,
        y: NET_Y,
        vx: 0,
        vy: -3,
        speed: 3,
        height: NET_HEIGHT_FACTOR + 0.1,
        heightVel: 0,
      };
      s.lastHitter = 1;
      const r = checkNetCollision(s);
      expect(r.netFault).toBeFalsy();
    });

    it("stops ball velocity on net hit", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: NET_Y, vx: 2, vy: -3, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 1;
      const r = checkNetCollision(s);
      expect(r.ball.vx).toBe(0);
      expect(r.ball.vy).toBe(0);
    });

    it("does not trigger when ball is far from net", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: 350, vx: 0, vy: -3, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 1;
      const r = checkNetCollision(s);
      expect(r.netFault).toBeFalsy();
    });
  });

  describe("checkOutOfBounds", () => {
    it("ball past left sideline → WIDE", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: COURT_LEFT - 15, y: 300, vx: -3, vy: 0, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 1;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.WIDE);
      expect(r.pointWinner).toBe(2); // hitter loses
    });

    it("ball past right sideline → WIDE", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: COURT_RIGHT + 15, y: 300, vx: 3, vy: 0, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 2;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.WIDE);
      expect(r.pointWinner).toBe(1);
    });

    it("ball past P2 baseline (top) → LONG if hitter was P1", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: COURT_TOP - 25, vx: 0, vy: -3, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 1;
      s.rallyCount = 2; // not a serve
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.LONG);
      expect(r.pointWinner).toBe(2);
    });

    it("ball past P1 baseline (bottom) → LONG if hitter was P2", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: COURT_BOTTOM + 25, vx: 0, vy: 3, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 2;
      s.rallyCount = 2;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.LONG);
      expect(r.pointWinner).toBe(1);
    });

    it("unreturned serve past baseline → ACE", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: COURT_TOP - 25, vx: 0, vy: -5, speed: 5, height: 0, heightVel: 0 };
      s.lastHitter = 1;
      s.rallyCount = 0; // serve, not returned
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.ACE);
      expect(r.pointWinner).toBe(1); // server wins on ace
    });

    it("ball speed below MIN_SPEED with height=0 → DEAD ball", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: 320,
        y: 350,
        vx: 0.5,
        vy: -0.5,
        speed: BALL_MIN_SPEED - 0.1,
        height: 0,
        heightVel: 0,
      };
      s.lastHitter = 1;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.DEAD);
    });

    it("ball still in court → no out event", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: 300, vx: 2, vy: -3, speed: 4, height: 0.3, heightVel: 0 };
      s.lastHitter = 1;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBeFalsy();
    });

    it("ball height > 0 past baseline → NOT out yet (still in air)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: 320,
        y: COURT_TOP - 25,
        vx: 0,
        vy: -3,
        speed: 3,
        height: 0.3,
        heightVel: -0.01,
      };
      s.lastHitter = 1;
      s.rallyCount = 2;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBeFalsy();
    });
  });

  describe("performServe", () => {
    it("launches ball from server position", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      const r = performServe(s);
      expect(r.ball.speed).toBeCloseTo(SERVE_SPEED, 1);
      expect(r.phase).toBe(PHASE.RALLY);
    });

    it("P1 serves upward (negative vy)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      const r = performServe(s);
      expect(r.ball.vy).toBeLessThan(0);
    });

    it("P2 serves downward (positive vy)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 2;
      const r = performServe(s);
      expect(r.ball.vy).toBeGreaterThan(0);
    });

    it("sets lastHitter to server", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      const r = performServe(s);
      expect(r.lastHitter).toBe(1);
    });

    it("resets rallyCount to 0", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      s.rallyCount = 5;
      const r = performServe(s);
      expect(r.rallyCount).toBe(0);
    });

    it("ball gets initial height > 0", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      const r = performServe(s);
      expect(r.ball.height).toBeGreaterThan(0);
    });

    it("sets serveEvent flag", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      const r = performServe(s);
      expect(r.serveEvent).toBe(true);
    });
  });

  describe("advanceScore — tennis scoring state machine", () => {
    function stateWithScore(p1Points, p2Points, p1Games, p2Games, mode, isTiebreak) {
      const s = createInitialState(mode || GAME_MODE.CLASSIC);
      s.p1Points = p1Points;
      s.p2Points = p2Points;
      s.p1Games = p1Games;
      s.p2Games = p2Games;
      s.isTiebreak = isTiebreak || false;
      s.server = 1;
      return s;
    }

    describe("normal scoring", () => {
      it("0→1 point (Love to 15)", () => {
        const s = stateWithScore(0, 0, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(1);
        expect(r.p2Points).toBe(0);
      });

      it("1→2 (15 to 30)", () => {
        const s = stateWithScore(1, 0, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(2);
      });

      it("2→3 (30 to 40)", () => {
        const s = stateWithScore(2, 0, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(3);
      });

      it("40-0 + P1 wins point → game won by P1", () => {
        const s = stateWithScore(3, 0, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(1);
        expect(r.p1Points).toBe(0);
        expect(r.p2Points).toBe(0);
        expect(r.announcement).toBe(ANNOUNCEMENT.GAME);
      });

      it("40-30 + P1 wins point → game won", () => {
        const s = stateWithScore(3, 2, 2, 1);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(3);
        expect(r.announcement).toBe(ANNOUNCEMENT.GAME);
      });
    });

    describe("deuce", () => {
      it("40-40 → announcement = DEUCE", () => {
        const s = stateWithScore(2, 3, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(3);
        expect(r.p2Points).toBe(3);
        expect(r.announcement).toBe(ANNOUNCEMENT.DEUCE);
      });

      it("deuce + P1 wins → ADVANTAGE_P1", () => {
        const s = stateWithScore(3, 3, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(4);
        expect(r.announcement).toBe(ANNOUNCEMENT.ADV_P1);
      });

      it("advantage P1 + P1 wins → game won", () => {
        const s = stateWithScore(4, 3, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(1);
        expect(r.p1Points).toBe(0);
        expect(r.announcement).toBe(ANNOUNCEMENT.GAME);
      });

      it("advantage P1 + P2 wins → back to DEUCE", () => {
        const s = stateWithScore(4, 3, 0, 0);
        s.pointWinner = 2;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(3);
        expect(r.p2Points).toBe(3);
        expect(r.announcement).toBe(ANNOUNCEMENT.DEUCE);
      });

      it("multiple deuce cycles (3+ rounds)", () => {
        // Simulate 3 deuce cycles
        let s = stateWithScore(3, 3, 0, 0);

        // Cycle 1: P1 advantage → back to deuce
        s.pointWinner = 1;
        s = advanceScore(s);
        expect(s.announcement).toBe(ANNOUNCEMENT.ADV_P1);
        s.pointWinner = 2;
        s = advanceScore(s);
        expect(s.announcement).toBe(ANNOUNCEMENT.DEUCE);

        // Cycle 2: P2 advantage → back to deuce
        s.pointWinner = 2;
        s = advanceScore(s);
        expect(s.announcement).toBe(ANNOUNCEMENT.ADV_P2);
        s.pointWinner = 1;
        s = advanceScore(s);
        expect(s.announcement).toBe(ANNOUNCEMENT.DEUCE);

        // Cycle 3: P1 advantage → wins
        s.pointWinner = 1;
        s = advanceScore(s);
        expect(s.announcement).toBe(ANNOUNCEMENT.ADV_P1);
        s.pointWinner = 1;
        s = advanceScore(s);
        expect(s.announcement).toBe(ANNOUNCEMENT.GAME);
        expect(s.p1Games).toBe(1);
      });
    });

    describe("game progression", () => {
      it("winning a game increments games count", () => {
        const s = stateWithScore(3, 0, 2, 1);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(3);
      });

      it("winning a game resets points to 0/0", () => {
        const s = stateWithScore(3, 2, 0, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(0);
        expect(r.p2Points).toBe(0);
      });

      it("winning a game switches server", () => {
        const s = stateWithScore(3, 0, 0, 0);
        s.server = 1;
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.server).toBe(2);
      });
    });

    describe("Classic mode — set win", () => {
      it("6-0 → set won", () => {
        const s = stateWithScore(3, 0, 5, 0);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(6);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("6-4 → set won", () => {
        const s = stateWithScore(3, 0, 5, 4);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(6);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("6-5 → NOT won (need 2 difference)", () => {
        const s = stateWithScore(3, 0, 5, 5);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(6);
        expect(r.phase).not.toBe(PHASE.GAME_OVER);
      });

      it("7-5 → set won", () => {
        const s = stateWithScore(3, 0, 6, 5);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(7);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("6-6 → tiebreak starts", () => {
        const s = stateWithScore(3, 0, 5, 6);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(6);
        expect(r.isTiebreak).toBe(true);
        expect(r.announcement).toBe(ANNOUNCEMENT.TIEBREAK);
      });
    });

    describe("tiebreak scoring", () => {
      it("7-0 → tiebreak won", () => {
        const s = stateWithScore(6, 0, 6, 6, GAME_MODE.CLASSIC, true);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(7);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
        expect(r.p1Games).toBe(7);
      });

      it("7-5 → tiebreak won", () => {
        const s = stateWithScore(6, 5, 6, 6, GAME_MODE.CLASSIC, true);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("7-6 → NOT won (need 2 difference)", () => {
        const s = stateWithScore(6, 6, 6, 6, GAME_MODE.CLASSIC, true);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Points).toBe(7);
        expect(r.phase).not.toBe(PHASE.GAME_OVER);
      });

      it("8-6 → tiebreak won", () => {
        const s = stateWithScore(7, 6, 6, 6, GAME_MODE.CLASSIC, true);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("server rotates: every 2 points after first point", () => {
        let s = stateWithScore(0, 0, 6, 6, GAME_MODE.CLASSIC, true);
        s.server = 1;

        // Point 1: server changes after 1st point
        s.pointWinner = 1;
        s = advanceScore(s);
        expect(s.server).toBe(2);

        // Point 2: no change yet (need 2 more after first)
        s.pointWinner = 2;
        s = advanceScore(s);
        expect(s.server).toBe(2);

        // Point 3: server changes (2 points since last rotation)
        s.pointWinner = 1;
        s = advanceScore(s);
        expect(s.server).toBe(1);
      });
    });

    describe("Quick Match mode", () => {
      it("first to 3 games wins (3-0)", () => {
        const s = stateWithScore(3, 0, 2, 0, GAME_MODE.QUICK);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(3);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("3-2 is valid win (no need for 2 difference)", () => {
        const s = stateWithScore(3, 0, 2, 2, GAME_MODE.QUICK);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(3);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("no tiebreak possible", () => {
        // In quick mode, max games is 3 so 6-6 is impossible
        const s = stateWithScore(3, 0, 2, 2, GAME_MODE.QUICK);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.isTiebreak).toBeFalsy();
      });
    });

    describe("Sudden Death mode", () => {
      it("each point = game won", () => {
        const s = stateWithScore(0, 0, 0, 0, GAME_MODE.SUDDEN_DEATH);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(1);
        expect(r.p1Points).toBe(0); // points reset
      });

      it("first to 6 games wins", () => {
        const s = stateWithScore(0, 0, 5, 3, GAME_MODE.SUDDEN_DEATH);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(6);
        expect(r.phase).toBe(PHASE.GAME_OVER);
        expect(r.winner).toBe(1);
      });

      it("no deuce, no advantage", () => {
        // In sudden death, each point wins a game immediately
        // So deuce is impossible
        const s = stateWithScore(0, 0, 3, 3, GAME_MODE.SUDDEN_DEATH);
        s.pointWinner = 1;
        const r = advanceScore(s);
        expect(r.p1Games).toBe(4);
        expect(r.announcement).toBe(ANNOUNCEMENT.GAME);
        expect(r.phase).not.toBe(PHASE.GAME_OVER); // not yet 6
      });
    });
  });

  describe("shouldChangeover", () => {
    it("changeover after game 1 (total odd)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Games = 1;
      s.p2Games = 0;
      expect(shouldChangeover(s)).toBe(true);
    });

    it("no changeover after game 2 (total even)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Games = 1;
      s.p2Games = 1;
      expect(shouldChangeover(s)).toBe(false);
    });

    it("changeover after game 3", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Games = 2;
      s.p2Games = 1;
      expect(shouldChangeover(s)).toBe(true);
    });

    it("no changeover at 0 total games", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(shouldChangeover(s)).toBe(false);
    });

    it("tiebreak: changeover every 6 points", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.isTiebreak = true;
      s.p1Points = 3;
      s.p2Points = 3;
      expect(shouldChangeover(s)).toBe(true); // 6 total points

      s.p1Points = 4;
      s.p2Points = 3;
      expect(shouldChangeover(s)).toBe(false); // 7 total
    });
  });

  describe("resetForNextPoint", () => {
    it("resets ball to center", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.ball = { x: 100, y: 100, vx: 5, vy: -3, speed: 6, height: 0.5, heightVel: 0.02 };
      const r = resetForNextPoint(s);
      expect(r.ball.vx).toBe(0);
      expect(r.ball.vy).toBe(0);
      expect(r.ball.speed).toBe(0);
    });

    it("clears event flags", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.hitEvent = true;
      s.serveEvent = true;
      s.netFault = true;
      s.outOfBounds = true;
      const r = resetForNextPoint(s);
      expect(r.hitEvent).toBe(false);
      expect(r.serveEvent).toBe(false);
      expect(r.netFault).toBe(false);
      expect(r.outOfBounds).toBe(false);
    });

    it("preserves score and server", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Points = 2;
      s.p2Points = 1;
      s.p1Games = 3;
      s.p2Games = 2;
      s.server = 2;
      const r = resetForNextPoint(s);
      expect(r.p1Points).toBe(2);
      expect(r.p2Points).toBe(1);
      expect(r.p1Games).toBe(3);
      expect(r.p2Games).toBe(2);
      expect(r.server).toBe(2);
    });

    it("transitions to SERVING phase", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.POINT;
      const r = resetForNextPoint(s);
      expect(r.phase).toBe(PHASE.SERVING);
    });
  });

  describe("clearEventFlags", () => {
    it("clears all event flags", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.hitEvent = true;
      s.serveEvent = true;
      s.netFault = true;
      s.outOfBounds = true;
      s.faultEvent = true;
      s.pointWinner = 1;
      s.announcement = ANNOUNCEMENT.DEUCE;
      s.outType = OUT_TYPE.WIDE;
      const r = clearEventFlags(s);
      expect(r.hitEvent).toBe(false);
      expect(r.serveEvent).toBe(false);
      expect(r.netFault).toBe(false);
      expect(r.outOfBounds).toBe(false);
      expect(r.faultEvent).toBe(false);
      expect(r.pointWinner).toBe(0);
      expect(r.announcement).toBe(ANNOUNCEMENT.NONE);
      expect(r.outType).toBe(OUT_TYPE.NONE);
    });
  });

  describe("checkServeLanding", () => {
    function makeServeState(srv, ballX, ballY, totalPoints, isSecondServe) {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.server = srv;
      s.rallyCount = 0; // serve not yet returned
      s.totalPointsInGame = totalPoints || 0;
      s.isSecondServe = isSecondServe || false;
      s.ball = { x: ballX, y: ballY, vx: 0, vy: 0, speed: 0, height: 0, heightVel: 0 };
      return s;
    }

    it("ball in correct service box → no fault", () => {
      // P1 serves, deuce court (totalPoints=0), target box = P2 side right half
      const s = makeServeState(1, CENTER_LINE_X + 30, COURT_TOP + 40, 0);
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBeFalsy();
    });

    it("ball outside service box → first serve fault → second serve", () => {
      // P1 serves, ball lands outside the box
      const s = makeServeState(1, COURT_LEFT - 5, COURT_TOP + 40, 0, false);
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBe(true);
      expect(r.isSecondServe).toBe(true);
      expect(r.phase).toBe(PHASE.SERVING);
    });

    it("second serve fault → double fault → point to receiver", () => {
      const s = makeServeState(1, COURT_LEFT - 5, COURT_TOP + 40, 0, true);
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBe(true);
      expect(r.pointWinner).toBe(2); // receiver wins
      expect(r.outOfBounds).toBe(true);
    });

    it("does not check if rally has started (rallyCount > 0)", () => {
      const s = makeServeState(1, COURT_LEFT - 50, COURT_TOP + 40, 0);
      s.rallyCount = 1;
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBeFalsy();
    });

    it("does not check if ball is still in the air", () => {
      const s = makeServeState(1, COURT_LEFT - 50, COURT_TOP + 40, 0);
      s.ball.height = 0.5;
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBeFalsy();
    });

    it("P2 serve: correct box on deuce court", () => {
      // P2 serves to P1's side (bottom), deuce court = left half
      const s = makeServeState(2, COURT_LEFT + 30, SERVICE_LINE_BOTTOM + 30, 0);
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBeFalsy();
    });

    it("P2 serve: ball outside box → fault", () => {
      const s = makeServeState(2, COURT_RIGHT + 5, SERVICE_LINE_BOTTOM + 30, 0, false);
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBe(true);
      expect(r.isSecondServe).toBe(true);
    });

    it("ad court (totalPoints=1) uses opposite half", () => {
      // P1 serves, ad court → left half of P2 side
      const s = makeServeState(1, CENTER_LINE_X - 30, COURT_TOP + 40, 1);
      const r = checkServeLanding(s);
      expect(r.faultEvent).toBeFalsy();
    });

    it("first serve fault resets ball and serve timer", () => {
      const s = makeServeState(1, COURT_LEFT - 5, COURT_TOP + 40, 0, false);
      const r = checkServeLanding(s);
      expect(r.ball.vx).toBe(0);
      expect(r.ball.vy).toBe(0);
      expect(r.serveTimer).toBe(SERVE_TIMEOUT_FRAMES);
    });
  });

  describe("performServe — additional cases", () => {
    it("second serve has slower speed (80%)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      s.isSecondServe = true;
      const r = performServe(s);
      expect(r.ball.speed).toBeCloseTo(SERVE_SPEED * 0.8, 1);
    });

    it("does not produce NaN velocities", () => {
      // Even with extreme position overlap, dist guard prevents NaN
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.SERVING;
      s.server = 1;
      s.p1x = CENTER_LINE_X + 70;
      s.p1y = SERVICE_LINE_TOP + 40 + 15;
      const r = performServe(s);
      expect(Number.isNaN(r.ball.vx)).toBe(false);
      expect(Number.isNaN(r.ball.vy)).toBe(false);
    });
  });

  describe("advanceScore — edge cases", () => {
    it("pointWinner=0 → no-op", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.pointWinner = 0;
      const r = advanceScore(s);
      expect(r).toBe(s); // exact same reference
    });
  });

  describe("checkSetWin — direct tests", () => {
    it("Classic 6-0 → P1 wins", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Games = 6;
      s.p2Games = 0;
      const r = checkSetWin(s);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(1);
    });

    it("Classic 5-5 → no winner", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Games = 5;
      s.p2Games = 5;
      const r = checkSetWin(s);
      expect(r.phase).not.toBe(PHASE.GAME_OVER);
    });

    it("Classic 6-6 → tiebreak", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1Games = 6;
      s.p2Games = 6;
      const r = checkSetWin(s);
      expect(r.isTiebreak).toBe(true);
    });

    it("Quick 3-2 → P1 wins", () => {
      const s = createInitialState(GAME_MODE.QUICK);
      s.p1Games = 3;
      s.p2Games = 2;
      const r = checkSetWin(s);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(1);
    });

    it("Sudden Death 6-5 → P1 wins (no win-by-2)", () => {
      const s = createInitialState(GAME_MODE.SUDDEN_DEATH);
      s.p1Games = 6;
      s.p2Games = 5;
      const r = checkSetWin(s);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(1);
    });

    it("Sudden Death 5-5 → no winner", () => {
      const s = createInitialState(GAME_MODE.SUDDEN_DEATH);
      s.p1Games = 5;
      s.p2Games = 5;
      const r = checkSetWin(s);
      expect(r.phase).not.toBe(PHASE.GAME_OVER);
    });
  });

  describe("Sudden Death — 6-6 bug fix", () => {
    function stateWithScore(p1Points, p2Points, p1Games, p2Games, mode) {
      const s = createInitialState(mode);
      s.p1Points = p1Points;
      s.p2Points = p2Points;
      s.p1Games = p1Games;
      s.p2Games = p2Games;
      s.server = 1;
      return s;
    }

    it("Sudden Death: 5-5 + P1 wins → P1 wins (6-5, no win-by-2 needed)", () => {
      const s = stateWithScore(0, 0, 5, 5, GAME_MODE.SUDDEN_DEATH);
      s.pointWinner = 1;
      const r = advanceScore(s);
      expect(r.p1Games).toBe(6);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(1);
    });

    it("Sudden Death: never reaches 6-6 (game ends at 6-5)", () => {
      // P1 at 5 games, P2 at 5 games → P2 wins next point
      const s = stateWithScore(0, 0, 5, 5, GAME_MODE.SUDDEN_DEATH);
      s.pointWinner = 2;
      const r = advanceScore(s);
      expect(r.p2Games).toBe(6);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(2);
    });

    it("Sudden Death: no tiebreak possible", () => {
      const s = stateWithScore(0, 0, 5, 5, GAME_MODE.SUDDEN_DEATH);
      s.pointWinner = 1;
      const r = advanceScore(s);
      expect(r.isTiebreak).toBeFalsy();
    });
  });

  describe("P2 winning — mirror symmetry", () => {
    function stateWithScore(p1Points, p2Points, p1Games, p2Games, mode, isTiebreak) {
      const s = createInitialState(mode || GAME_MODE.CLASSIC);
      s.p1Points = p1Points;
      s.p2Points = p2Points;
      s.p1Games = p1Games;
      s.p2Games = p2Games;
      s.isTiebreak = isTiebreak || false;
      s.server = 1;
      return s;
    }

    it("P2 wins game at 40-0", () => {
      const s = stateWithScore(0, 3, 0, 0);
      s.pointWinner = 2;
      const r = advanceScore(s);
      expect(r.p2Games).toBe(1);
      expect(r.announcement).toBe(ANNOUNCEMENT.GAME);
    });

    it("P2 wins set at 6-4", () => {
      const s = stateWithScore(0, 3, 4, 5);
      s.pointWinner = 2;
      const r = advanceScore(s);
      expect(r.p2Games).toBe(6);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(2);
    });

    it("P2 wins Classic tiebreak 7-5", () => {
      const s = stateWithScore(5, 6, 6, 6, GAME_MODE.CLASSIC, true);
      s.pointWinner = 2;
      const r = advanceScore(s);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(2);
    });

    it("P2 wins Quick 3-0", () => {
      const s = stateWithScore(0, 3, 0, 2, GAME_MODE.QUICK);
      s.pointWinner = 2;
      const r = advanceScore(s);
      expect(r.p2Games).toBe(3);
      expect(r.phase).toBe(PHASE.GAME_OVER);
      expect(r.winner).toBe(2);
    });

    it("P2 advantage then wins game", () => {
      const s = stateWithScore(3, 4, 0, 0);
      s.pointWinner = 2;
      const r = advanceScore(s);
      expect(r.p2Games).toBe(1);
      expect(r.announcement).toBe(ANNOUNCEMENT.GAME);
    });
  });

  describe("checkNetCollision — P2 side", () => {
    it("P2 hitting into net → P1 wins point", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: NET_Y, vx: 0, vy: 3, speed: 3, height: 0, heightVel: 0 };
      s.lastHitter = 2;
      const r = checkNetCollision(s);
      expect(r.netFault).toBe(true);
      expect(r.pointWinner).toBe(1);
    });
  });

  describe("checkOutOfBounds — P2 ACE", () => {
    it("P2 unreturned serve past P1 baseline → ACE for P2", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: COURT_BOTTOM + 25, vx: 0, vy: 5, speed: 5, height: 0, heightVel: 0 };
      s.lastHitter = 2;
      s.rallyCount = 0;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.ACE);
      expect(r.pointWinner).toBe(2);
    });
  });

  describe("checkOutOfBounds — dead ball with lastHitter=0", () => {
    it("dead ball with no hitter → does NOT trigger (safety guard)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: 320,
        y: 350,
        vx: 0.1,
        vy: -0.1,
        speed: BALL_MIN_SPEED - 0.1,
        height: 0,
        heightVel: 0,
      };
      s.lastHitter = 0;
      const r = checkOutOfBounds(s);
      // lastHitter=0 means no one has hit yet — can't assign a point winner
      expect(r.outOfBounds).toBeFalsy();
    });

    it("dead ball with lastHitter=1 → P2 wins", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: 320,
        y: 350,
        vx: 0.1,
        vy: -0.1,
        speed: BALL_MIN_SPEED - 0.1,
        height: 0,
        heightVel: 0,
      };
      s.lastHitter = 1;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.DEAD);
      expect(r.pointWinner).toBe(2);
    });

    it("dead ball with lastHitter=2 → P1 wins", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = {
        x: 320,
        y: 350,
        vx: 0.1,
        vy: -0.1,
        speed: BALL_MIN_SPEED - 0.1,
        height: 0,
        heightVel: 0,
      };
      s.lastHitter = 2;
      const r = checkOutOfBounds(s);
      expect(r.outOfBounds).toBe(true);
      expect(r.outType).toBe(OUT_TYPE.DEAD);
      expect(r.pointWinner).toBe(1);
    });
  });

  describe("rallyCount overflow", () => {
    it("rallyCount increments beyond 255 in physics", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.rallyCount = 254;
      s.ball = { x: 320, y: 400, vx: 0, vy: 4, speed: 4, height: 0.1, heightVel: 0 };
      s.lastHitter = 2;
      s.p1x = 320;
      s.p1y = 400;
      const r = checkHitZone(s, 1);
      if (r.hitEvent) {
        expect(r.rallyCount).toBe(255);
      }
    });
  });

  describe("updateBall — zero velocity edge case", () => {
    it("does not produce NaN with zero vx/vy", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.phase = PHASE.RALLY;
      s.ball = { x: 320, y: 240, vx: 0, vy: 0, speed: 3, height: 0.5, heightVel: 0 };
      const r = updateBall(s);
      expect(Number.isNaN(r.ball.vx)).toBe(false);
      expect(Number.isNaN(r.ball.vy)).toBe(false);
      expect(r.ball.vx).toBe(0);
      expect(r.ball.vy).toBe(0);
    });
  });
});
