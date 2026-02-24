import { describe, it, expect } from "vitest";
import {
  CANVAS_W,
  CANVAS_H,
  RING_LEFT,
  RING_RIGHT,
  RING_TOP,
  RING_BOTTOM,
  BOXER_BODY_RADIUS,
  BOXER_SPEED,
  PUNCH_RANGE,
  PUNCH_DURATION,
  PUNCH_COOLDOWN,
  ROUND_DURATION,
  KO_SCORE,
  ROUNDS_TO_WIN,
  createInitialState,
  clampToRing,
  moveBoxer,
  startPunch,
  tickPunchTimers,
  getFistPosition,
  checkPunchHit,
  tickRoundTimer,
  checkRoundEnd,
  advanceRound,
  resetForNewRound,
} from "../../../../js/lib/games/hex_boxing/physics.js";
import { PHASE, PUNCH_STATE } from "../../../../js/lib/games/hex_boxing/protocol.js";

describe("Hex Boxing Physics", () => {
  describe("createInitialState", () => {
    it("creates state with correct spawn positions", () => {
      const s = createInitialState();
      // P1 on left, P2 on right
      expect(s.b1x).toBeLessThan(CANVAS_W / 2);
      expect(s.b2x).toBeGreaterThan(CANVAS_W / 2);
      // Both at same vertical center
      expect(s.b1y).toBe(s.b2y);
    });

    it("P1 faces right (dir=0), P2 faces left (dir=4)", () => {
      const s = createInitialState();
      expect(s.b1dir).toBe(0);
      expect(s.b2dir).toBe(4);
    });

    it("starts in WAITING phase with full timer", () => {
      const s = createInitialState();
      expect(s.phase).toBe(PHASE.WAITING);
      expect(s.roundTimer).toBe(ROUND_DURATION);
      expect(s.round).toBe(1);
      expect(s.score1).toBe(0);
      expect(s.score2).toBe(0);
    });

    it("all punch states are IDLE", () => {
      const s = createInitialState();
      expect(s.b1punchState).toBe(PUNCH_STATE.IDLE);
      expect(s.b2punchState).toBe(PUNCH_STATE.IDLE);
    });
  });

  describe("clampToRing", () => {
    it("clamps X to ring boundaries", () => {
      const r1 = clampToRing(0, 200);
      expect(r1.x).toBe(RING_LEFT + BOXER_BODY_RADIUS);

      const r2 = clampToRing(CANVAS_W, 200);
      expect(r2.x).toBe(RING_RIGHT - BOXER_BODY_RADIUS);
    });

    it("clamps Y to ring boundaries", () => {
      const r1 = clampToRing(200, 0);
      expect(r1.y).toBe(RING_TOP + BOXER_BODY_RADIUS);

      const r2 = clampToRing(200, CANVAS_H);
      expect(r2.y).toBe(RING_BOTTOM - BOXER_BODY_RADIUS);
    });

    it("does not modify positions inside ring", () => {
      const r = clampToRing(320, 240);
      expect(r.x).toBe(320);
      expect(r.y).toBe(240);
    });
  });

  describe("moveBoxer", () => {
    it("moves P1 right (dir=0)", () => {
      const s = createInitialState();
      const s2 = moveBoxer(s, 1, 0);
      expect(s2.b1x).toBeCloseTo(s.b1x + BOXER_SPEED, 1);
      expect(s2.b1y).toBe(s.b1y);
      expect(s2.b1dir).toBe(0);
    });

    it("moves P2 left (dir=4)", () => {
      const s = createInitialState();
      const s2 = moveBoxer(s, 2, 4);
      expect(s2.b2x).toBeCloseTo(s.b2x - BOXER_SPEED, 1);
    });

    it("moves diagonally (dir=1 = down-right)", () => {
      const s = createInitialState();
      const s2 = moveBoxer(s, 1, 1);
      expect(s2.b1x).toBeGreaterThan(s.b1x);
      expect(s2.b1y).toBeGreaterThan(s.b1y);
    });

    it("updates facing direction", () => {
      const s = createInitialState();
      const s2 = moveBoxer(s, 1, 6); // up
      expect(s2.b1dir).toBe(6);
    });

    it("clamps to ring boundary", () => {
      const s = { ...createInitialState(), b1x: RING_LEFT + BOXER_BODY_RADIUS + 1 };
      const s2 = moveBoxer(s, 1, 4); // move left into wall
      expect(s2.b1x).toBeGreaterThanOrEqual(RING_LEFT + BOXER_BODY_RADIUS);
    });

    it("resolves body collision (push apart)", () => {
      const s = {
        ...createInitialState(),
        b1x: 300,
        b1y: 240,
        b2x: 310,
        b2y: 240,
      };
      // Move P1 right toward P2
      const s2 = moveBoxer(s, 1, 0);
      // P1 should be pushed back so bodies don't overlap
      const dist = Math.sqrt(
        (s2.b1x - s2.b2x) * (s2.b1x - s2.b2x) + (s2.b1y - s2.b2y) * (s2.b1y - s2.b2y),
      );
      expect(dist).toBeGreaterThanOrEqual(BOXER_BODY_RADIUS * 2 - 0.01);
    });

    it("handles all 8 directions without error", () => {
      const s = createInitialState();
      for (let dir = 0; dir < 8; dir++) {
        const s2 = moveBoxer(s, 1, dir);
        expect(s2.b1x).toBeDefined();
        expect(s2.b1y).toBeDefined();
      }
    });
  });

  describe("startPunch", () => {
    it("starts punch when idle", () => {
      const s = createInitialState();
      const s2 = startPunch(s, 1);
      expect(s2.b1punchState).toBe(PUNCH_STATE.PUNCHING);
      expect(s2.b1punchTimer).toBe(PUNCH_DURATION);
    });

    it("does nothing when already punching", () => {
      const s = { ...createInitialState(), b1punchState: PUNCH_STATE.PUNCHING, b1punchTimer: 5 };
      const s2 = startPunch(s, 1);
      expect(s2.b1punchTimer).toBe(5); // unchanged
    });

    it("does nothing during cooldown", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.COOLDOWN,
        b1cooldownTimer: 5,
      };
      const s2 = startPunch(s, 1);
      expect(s2.b1punchState).toBe(PUNCH_STATE.COOLDOWN);
    });

    it("alternates arms", () => {
      const s = createInitialState();
      expect(s.b1arm).toBe(0);
      const s2 = startPunch(s, 1);
      expect(s2.b1arm).toBe(1); // switched from 0 to 1

      // Simulate punch completing and starting again
      const s3 = {
        ...s2,
        b1punchState: PUNCH_STATE.IDLE,
        b1punchTimer: 0,
        b1cooldownTimer: 0,
      };
      const s4 = startPunch(s3, 1);
      expect(s4.b1arm).toBe(0); // switched back
    });
  });

  describe("tickPunchTimers", () => {
    it("decrements punch timer during PUNCHING", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: 5,
      };
      const s2 = tickPunchTimers(s);
      expect(s2.b1punchTimer).toBe(4);
      expect(s2.b1punchState).toBe(PUNCH_STATE.PUNCHING);
    });

    it("transitions PUNCHING to COOLDOWN when timer reaches 1", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: 1,
      };
      const s2 = tickPunchTimers(s);
      expect(s2.b1punchState).toBe(PUNCH_STATE.COOLDOWN);
      expect(s2.b1punchTimer).toBe(0);
      expect(s2.b1cooldownTimer).toBe(PUNCH_COOLDOWN);
    });

    it("decrements cooldown timer during COOLDOWN", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.COOLDOWN,
        b1cooldownTimer: 5,
      };
      const s2 = tickPunchTimers(s);
      expect(s2.b1cooldownTimer).toBe(4);
    });

    it("transitions COOLDOWN to IDLE when timer reaches 1", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.COOLDOWN,
        b1cooldownTimer: 1,
      };
      const s2 = tickPunchTimers(s);
      expect(s2.b1punchState).toBe(PUNCH_STATE.IDLE);
      expect(s2.b1cooldownTimer).toBe(0);
    });

    it("does nothing when IDLE", () => {
      const s = createInitialState();
      const s2 = tickPunchTimers(s);
      expect(s2.b1punchState).toBe(PUNCH_STATE.IDLE);
    });

    it("ticks both boxers independently", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: 3,
        b2punchState: PUNCH_STATE.COOLDOWN,
        b2cooldownTimer: 5,
      };
      const s2 = tickPunchTimers(s);
      expect(s2.b1punchTimer).toBe(2);
      expect(s2.b2cooldownTimer).toBe(4);
    });
  });

  describe("getFistPosition", () => {
    it("returns null when not punching", () => {
      const s = createInitialState();
      expect(getFistPosition(s, 1)).toBeNull();
    });

    it("returns fist position when punching", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: Math.ceil(PUNCH_DURATION / 2),
        b1dir: 0,
      };
      const fist = getFistPosition(s, 1);
      expect(fist).not.toBeNull();
      // Fist should be to the right of the body (dir=0 = right)
      expect(fist.x).toBeGreaterThan(s.b1x);
    });

    it("fist extends in facing direction", () => {
      // Facing left (dir=4)
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: Math.ceil(PUNCH_DURATION / 2),
        b1dir: 4,
      };
      const fist = getFistPosition(s, 1);
      expect(fist.x).toBeLessThan(s.b1x);
    });

    it("fist at punch start (timer=PUNCH_DURATION) is near body", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: PUNCH_DURATION,
        b1dir: 0,
      };
      const fist = getFistPosition(s, 1);
      // At start, progress=0, extension=0, reach=BOXER_BODY_RADIUS
      expect(fist.x).toBeCloseTo(s.b1x + BOXER_BODY_RADIUS, 1);
    });

    it("fist at punch end (timer=1) is near body", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: 1,
        b1dir: 0,
      };
      const fist = getFistPosition(s, 1);
      // At end, progress=1, extension=0, reach=BOXER_BODY_RADIUS
      expect(fist.x).toBeCloseTo(s.b1x + BOXER_BODY_RADIUS, 1);
    });

    it("fist at max extension (mid-punch) reaches full range", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: Math.ceil(PUNCH_DURATION / 2),
        b1dir: 0,
      };
      const fist = getFistPosition(s, 1);
      // At mid-punch, extension=1.0, reach=BOXER_BODY_RADIUS + PUNCH_RANGE
      expect(fist.x).toBeCloseTo(s.b1x + BOXER_BODY_RADIUS + PUNCH_RANGE, 1);
    });

    it("returns null during COOLDOWN", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.COOLDOWN,
        b1cooldownTimer: 5,
      };
      expect(getFistPosition(s, 1)).toBeNull();
    });

    it("works for diagonal directions", () => {
      // dir=1 = down-right
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: Math.ceil(PUNCH_DURATION / 2),
        b1dir: 1,
      };
      const fist = getFistPosition(s, 1);
      expect(fist.x).toBeGreaterThan(s.b1x);
      expect(fist.y).toBeGreaterThan(s.b1y);
    });
  });

  describe("checkPunchHit", () => {
    // At mid-punch (timer = ceil(PUNCH_DURATION/2) = 5), progress = 0.5,
    // extension = 1.0 (max), reach = BOXER_BODY_RADIUS + PUNCH_RANGE = 32.
    // Fist hits if distance(fist, opponent_center) < FIST_RADIUS + BOXER_BODY_RADIUS = 11.
    // So opponent center should be near reach (32) from attacker center.
    // impactDist = bodyDist - BOXER_BODY_RADIUS * 2 determines scoring zone.
    function setupHitScenario(bodyDist) {
      // Place boxers at specific distance, P1 punching right toward P2
      const s = {
        ...createInitialState(),
        b1x: 200,
        b1y: 240,
        b1dir: 0, // facing right
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: Math.ceil(PUNCH_DURATION / 2), // mid-punch (max extension)
        b2x: 200 + bodyDist,
        b2y: 240,
        b2dir: 4,
      };
      return s;
    }

    it("scores 3 points for close hit", () => {
      // bodyDist=26 → impactDist = 26 - 16 = 10 < CLOSE_DIST(12) → 3 points
      // fist at x=232, opponent at x=226, dist=6 < 11 → hit
      const s = setupHitScenario(26);
      const s2 = checkPunchHit(s, 1);
      expect(s2.score1).toBe(3);
      expect(s2.lastHitPlayer).toBe(1);
      expect(s2.lastHitPoints).toBe(3);
    });

    it("scores 2 points for medium hit", () => {
      // bodyDist=30 → impactDist = 30 - 16 = 14, CLOSE_DIST(12) <= 14 < MEDIUM_DIST(18) → 2 points
      // fist at x=232, opponent at x=230, dist=2 < 11 → hit
      const s = setupHitScenario(30);
      const s2 = checkPunchHit(s, 1);
      expect(s2.lastHitPlayer).toBe(1);
      expect(s2.lastHitPoints).toBe(2);
    });

    it("misses when opponent is out of range", () => {
      const s = setupHitScenario(BOXER_BODY_RADIUS * 2 + PUNCH_RANGE + 20);
      const s2 = checkPunchHit(s, 1);
      expect(s2.score1).toBe(0);
      expect(s2.lastHitPlayer).toBe(0);
    });

    it("does nothing when not punching", () => {
      const s = createInitialState();
      const s2 = checkPunchHit(s, 1);
      expect(s2.score1).toBe(0);
    });

    it("ends punch on hit (prevents multi-hit)", () => {
      const s = setupHitScenario(26);
      const s2 = checkPunchHit(s, 1);
      expect(s2.b1punchState).toBe(PUNCH_STATE.COOLDOWN);
    });

    it("P2 can also score", () => {
      // P2 at x=300, facing left (dir=4), fist extends to x=300-32=268
      // P1 at x=274, dist from fist to P1 center = |268-274| = 6 < 11 → hit
      const s = {
        ...createInitialState(),
        b2x: 300,
        b2y: 240,
        b2dir: 4, // facing left
        b2punchState: PUNCH_STATE.PUNCHING,
        b2punchTimer: Math.ceil(PUNCH_DURATION / 2),
        b1x: 274,
        b1y: 240,
      };
      const s2 = checkPunchHit(s, 2);
      expect(s2.score2).toBeGreaterThan(0);
      expect(s2.lastHitPlayer).toBe(2);
    });

    it("scores 1 point for far hit", () => {
      // bodyDist=34 → impactDist = 34 - 16 = 18 >= MEDIUM_DIST(18) → 1 point
      // fist at x=232, opponent at x=234, dist=2 < 11 → hit
      const s = setupHitScenario(34);
      const s2 = checkPunchHit(s, 1);
      expect(s2.lastHitPlayer).toBe(1);
      expect(s2.lastHitPoints).toBe(1);
    });

    it("both boxers can score in same frame", () => {
      // P1 punching right, P2 punching left, both at max extension
      const s = {
        ...createInitialState(),
        b1x: 200,
        b1y: 240,
        b1dir: 0,
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: Math.ceil(PUNCH_DURATION / 2),
        b2x: 230,
        b2y: 240,
        b2dir: 4,
        b2punchState: PUNCH_STATE.PUNCHING,
        b2punchTimer: Math.ceil(PUNCH_DURATION / 2),
      };
      let s2 = checkPunchHit(s, 1);
      s2 = checkPunchHit(s2, 2);
      // Both should have scored (P1 hits P2 and P2 hits P1)
      expect(s2.score1).toBeGreaterThan(0);
      expect(s2.score2).toBeGreaterThan(0);
    });

    it("score caps at 255 (Uint8 max)", () => {
      const s = {
        ...setupHitScenario(26),
        score1: 254,
      };
      const s2 = checkPunchHit(s, 1);
      expect(s2.score1).toBeLessThanOrEqual(255);
    });

    it("does not score during COOLDOWN", () => {
      const s = {
        ...createInitialState(),
        b1x: 200,
        b1y: 240,
        b1dir: 0,
        b1punchState: PUNCH_STATE.COOLDOWN,
        b1cooldownTimer: 5,
        b2x: 226,
        b2y: 240,
      };
      const s2 = checkPunchHit(s, 1);
      expect(s2.score1).toBe(0);
    });
  });

  describe("tickRoundTimer", () => {
    it("decrements timer", () => {
      const s = { ...createInitialState(), roundTimer: 100 };
      const s2 = tickRoundTimer(s);
      expect(s2.roundTimer).toBe(99);
    });

    it("does not go below zero", () => {
      const s = { ...createInitialState(), roundTimer: 0 };
      const s2 = tickRoundTimer(s);
      expect(s2.roundTimer).toBe(0);
    });
  });

  describe("checkRoundEnd", () => {
    it("detects KO for P1 (score >= 100)", () => {
      const s = { ...createInitialState(), score1: KO_SCORE };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(1);
    });

    it("detects KO for P2", () => {
      const s = { ...createInitialState(), score2: KO_SCORE };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(2);
    });

    it("detects time up with P1 leading", () => {
      const s = { ...createInitialState(), roundTimer: 0, score1: 50, score2: 30 };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(1);
    });

    it("detects time up with P2 leading", () => {
      const s = { ...createInitialState(), roundTimer: 0, score1: 30, score2: 50 };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(2);
    });

    it("tie goes to P1", () => {
      const s = { ...createInitialState(), roundTimer: 0, score1: 50, score2: 50 };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(1);
    });

    it("returns not ended during active play", () => {
      const s = { ...createInitialState(), roundTimer: 3600, score1: 50, score2: 50 };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(false);
    });

    it("KO at exactly 100 points", () => {
      const s = { ...createInitialState(), score1: KO_SCORE };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
    });

    it("KO above 100 points (overflow from multi-point hit)", () => {
      const s = { ...createInitialState(), score1: KO_SCORE + 3 };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(1);
    });

    it("both at KO — P1 checked first wins", () => {
      const s = { ...createInitialState(), score1: KO_SCORE, score2: KO_SCORE };
      const result = checkRoundEnd(s);
      expect(result.ended).toBe(true);
      expect(result.roundWinner).toBe(1);
    });
  });

  describe("advanceRound", () => {
    it("increments winner round wins", () => {
      const s = createInitialState();
      const s2 = advanceRound(s, 1);
      expect(s2.roundWins1).toBe(1);
      expect(s2.roundWins2).toBe(0);
      expect(s2.phase).toBe(PHASE.ROUND_OVER);
    });

    it("detects match over when P1 wins enough rounds", () => {
      const s = { ...createInitialState(), roundWins1: ROUNDS_TO_WIN - 1 };
      const s2 = advanceRound(s, 1);
      expect(s2.phase).toBe(PHASE.MATCH_OVER);
    });

    it("detects match over when P2 wins enough rounds", () => {
      const s = { ...createInitialState(), roundWins2: ROUNDS_TO_WIN - 1 };
      const s2 = advanceRound(s, 2);
      expect(s2.phase).toBe(PHASE.MATCH_OVER);
    });

    it("sets koPlayer when KO occurred", () => {
      const s = { ...createInitialState(), score1: KO_SCORE };
      const s2 = advanceRound(s, 1);
      expect(s2.koPlayer).toBe(2); // P2 got knocked out
    });
  });

  describe("resetForNewRound", () => {
    it("resets positions and scores", () => {
      const s = {
        ...createInitialState(),
        b1x: 500,
        b1y: 100,
        score1: 75,
        score2: 40,
        round: 1,
        roundWins1: 1,
      };
      const s2 = resetForNewRound(s);
      expect(s2.score1).toBe(0);
      expect(s2.score2).toBe(0);
      expect(s2.b1x).toBeLessThan(CANVAS_W / 2);
      expect(s2.b2x).toBeGreaterThan(CANVAS_W / 2);
    });

    it("preserves roundWins", () => {
      const s = { ...createInitialState(), roundWins1: 1, roundWins2: 0 };
      const s2 = resetForNewRound(s);
      expect(s2.roundWins1).toBe(1);
      expect(s2.roundWins2).toBe(0);
    });

    it("increments round counter", () => {
      const s = { ...createInitialState(), round: 1 };
      const s2 = resetForNewRound(s);
      expect(s2.round).toBe(2);
    });

    it("resets punch states", () => {
      const s = {
        ...createInitialState(),
        b1punchState: PUNCH_STATE.PUNCHING,
        b1punchTimer: 5,
      };
      const s2 = resetForNewRound(s);
      expect(s2.b1punchState).toBe(PUNCH_STATE.IDLE);
      expect(s2.b1punchTimer).toBe(0);
    });

    it("resets timer to full duration", () => {
      const s = { ...createInitialState(), roundTimer: 100 };
      const s2 = resetForNewRound(s);
      expect(s2.roundTimer).toBe(ROUND_DURATION);
    });
  });
});
