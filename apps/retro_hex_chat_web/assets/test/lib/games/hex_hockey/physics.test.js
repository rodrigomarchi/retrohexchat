import { describe, it, expect } from "vitest";
import { PHASE, GAME_MODE, EVENT } from "../../../../js/lib/games/hex_hockey/protocol.js";
import {
  RINK_LEFT,
  RINK_RIGHT,
  RINK_TOP,
  RINK_BOTTOM,
  RINK_CX,
  RINK_CY,
  GOAL_TOP,
  GOAL_BOTTOM,
  GOAL_LINE_LEFT,
  GOAL_LINE_RIGHT,
  GOAL_DEPTH,
  PLAYER_W,
  PUCK_R,
  createInitialState,
  resetForFaceoff,
  getGoalieXPositions,
  updatePlayer,
  updateGoalie,
  updatePuck,
  checkCapture,
  checkGoalieBlock,
  handleShoot,
  handleTackle,
  checkGoal,
  checkPuckStuck,
  advancePeriod,
  checkShowdownWin,
  determineWinner,
  packState,
  unpackState,
  COUNTDOWN_FRAME_INTERVAL,
  GOAL_CELEBRATION_FRAMES,
  STUN_DURATION,
  SHOWDOWN_TARGET,
} from "../../../../js/lib/games/hex_hockey/physics.js";

describe("hex_hockey_physics", () => {
  // ── createInitialState ──────────────────────────────────────

  describe("createInitialState", () => {
    it("creates state in WAITING phase", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.phase).toBe(PHASE.WAITING);
    });

    it("places players on opposite sides of center", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.p1.x).toBeLessThan(RINK_CX);
      expect(s.p2.x).toBeGreaterThan(RINK_CX);
      expect(s.p1.y).toBe(RINK_CY);
      expect(s.p2.y).toBe(RINK_CY);
    });

    it("places puck at center with zero velocity", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.puck.x).toBe(RINK_CX);
      expect(s.puck.y).toBe(RINK_CY);
      expect(s.puck.vx).toBe(0);
      expect(s.puck.vy).toBe(0);
      expect(s.puck.possessedBy).toBe(0);
    });

    it("initializes scores to zero", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.scoreP1).toBe(0);
      expect(s.scoreP2).toBe(0);
    });

    it("sets correct timer for CLASSIC mode (2 min × 60 fps)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.timerFrames).toBe(120 * 60);
      expect(s.period).toBe(1);
    });

    it("sets correct timer for BLITZ mode (3 min × 60 fps)", () => {
      const s = createInitialState(GAME_MODE.BLITZ);
      expect(s.timerFrames).toBe(180 * 60);
    });

    it("sets zero timer for SHOWDOWN mode", () => {
      const s = createInitialState(GAME_MODE.SHOWDOWN);
      expect(s.timerFrames).toBe(0);
    });

    it("starts with sidesSwapped = false", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.sidesSwapped).toBe(false);
    });

    it("no player has puck initially", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.p1.hasPuck).toBe(false);
      expect(s.p2.hasPuck).toBe(false);
    });

    it("no stun initially", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      expect(s.p1.stunTimer).toBe(0);
      expect(s.p2.stunTimer).toBe(0);
    });
  });

  // ── resetForFaceoff ─────────────────────────────────────────

  describe("resetForFaceoff", () => {
    it("resets all entities to center positions", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.x = 100;
      s.p1.y = 400;
      s.p1.hasPuck = true;
      s.p1.stunTimer = 10;
      s.puck.x = 50;
      s.puck.vx = 5;

      resetForFaceoff(s, null);

      expect(s.p1.x).toBeCloseTo(RINK_CX - 60, 0);
      expect(s.p1.y).toBe(RINK_CY);
      expect(s.p1.hasPuck).toBe(false);
      expect(s.p1.stunTimer).toBe(0);
      expect(s.puck.x).toBe(RINK_CX);
      expect(s.puck.vx).toBe(0);
      expect(s.puck.possessedBy).toBe(0);
    });

    it("swaps player positions when sidesSwapped", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.sidesSwapped = true;
      resetForFaceoff(s, null);

      // When swapped: P1 is on right side, P2 on left
      expect(s.p1.x).toBeGreaterThan(RINK_CX);
      expect(s.p2.x).toBeLessThan(RINK_CX);
    });

    it("resets puck stuck frames", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puckStuckFrames = 200;
      resetForFaceoff(s, null);
      expect(s.puckStuckFrames).toBe(0);
    });
  });

  // ── getGoalieXPositions ─────────────────────────────────────

  describe("getGoalieXPositions", () => {
    it("default: G1 on left, G2 on right", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const { g1x, g2x } = getGoalieXPositions(s);
      expect(g1x).toBeLessThan(RINK_CX);
      expect(g2x).toBeGreaterThan(RINK_CX);
    });

    it("swapped: G1 on right, G2 on left", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.sidesSwapped = true;
      const { g1x, g2x } = getGoalieXPositions(s);
      expect(g1x).toBeGreaterThan(RINK_CX);
      expect(g2x).toBeLessThan(RINK_CX);
    });
  });

  // ── updatePlayer ────────────────────────────────────────────

  describe("updatePlayer", () => {
    it("moves player right when right input pressed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const startX = s.p1.x;
      updatePlayer(s, { left: false, right: true, up: false, down: false, action: false }, true);
      expect(s.p1.x).toBeGreaterThan(startX);
      expect(s.p1.facing).toBe(0); // right
    });

    it("moves player diagonally with reduced speed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const startX = s.p1.x;
      const startY = s.p1.y;
      updatePlayer(s, { left: false, right: true, up: false, down: true, action: false }, true);
      const dx = s.p1.x - startX;
      const dy = s.p1.y - startY;
      // Diagonal distance should be same as cardinal speed
      const dist = Math.sqrt(dx * dx + dy * dy);
      expect(dist).toBeCloseTo(2.5, 1); // PLAYER_SPEED
    });

    it("does not move when stunned", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.stunTimer = 5;
      const startX = s.p1.x;
      updatePlayer(s, { left: false, right: true, up: false, down: false, action: false }, true);
      expect(s.p1.x).toBe(startX);
      expect(s.p1.stunTimer).toBe(4); // decremented
    });

    it("decrements stun timer each frame", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.stunTimer = 3;
      updatePlayer(s, { left: false, right: false, up: false, down: false, action: false }, true);
      expect(s.p1.stunTimer).toBe(2);
    });

    it("clamps player to rink bounds", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.x = RINK_LEFT + 1; // near left wall
      updatePlayer(s, { left: true, right: false, up: false, down: false, action: false }, true);
      expect(s.p1.x).toBeGreaterThanOrEqual(RINK_LEFT + PLAYER_W / 2);
    });

    it("carries puck when player has it", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.hasPuck = true;
      s.puck.possessedBy = 1;
      updatePlayer(s, { left: false, right: true, up: false, down: false, action: false }, true);
      // Puck should be near player (offset by stick)
      expect(Math.abs(s.puck.x - s.p1.x)).toBeLessThan(20);
    });

    it("does not move when no input", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const startX = s.p1.x;
      const startY = s.p1.y;
      updatePlayer(s, { left: false, right: false, up: false, down: false, action: false }, true);
      expect(s.p1.x).toBe(startX);
      expect(s.p1.y).toBe(startY);
    });

    it("cancels opposite directions", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const startX = s.p1.x;
      updatePlayer(s, { left: true, right: true, up: false, down: false, action: false }, true);
      expect(s.p1.x).toBe(startX); // no horizontal movement
    });

    it("clamps carried puck within rink bounds (no wall clipping)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.hasPuck = true;
      s.puck.possessedBy = 1;
      // Place player near left wall facing left
      s.p1.x = RINK_LEFT + PLAYER_W / 2 + 1;
      s.p1.y = RINK_CY;
      s.p1.facing = 4; // left
      updatePlayer(s, { left: false, right: false, up: false, down: false, action: false }, true);
      // Puck must not go below RINK_LEFT + PUCK_R
      expect(s.puck.x).toBeGreaterThanOrEqual(RINK_LEFT + PUCK_R);
    });

    it("clamps carried puck vertically too", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.hasPuck = true;
      s.puck.possessedBy = 1;
      // Place player near top wall facing up
      s.p1.x = RINK_CX;
      s.p1.y = RINK_TOP + PLAYER_W / 2 + 1;
      s.p1.facing = 2; // up
      updatePlayer(s, { left: false, right: false, up: false, down: false, action: false }, true);
      expect(s.puck.y).toBeGreaterThanOrEqual(RINK_TOP + PUCK_R);
    });
  });

  // ── updateGoalie ────────────────────────────────────────────

  describe("updateGoalie", () => {
    it("moves goalie toward puck Y", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.y = RINK_TOP + 60; // puck near top
      s.g1.y = RINK_CY; // goalie at center

      updateGoalie(s, true);
      expect(s.g1.y).toBeLessThan(RINK_CY); // moved toward puck
    });

    it("clamps goalie within goal area", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.y = RINK_TOP; // puck way up
      s.g1.y = GOAL_TOP - 10;

      updateGoalie(s, true);
      // Should not go too far from goal
      expect(s.g1.y).toBeGreaterThanOrEqual(GOAL_TOP - 10); // margin check
    });
  });

  // ── updatePuck ──────────────────────────────────────────────

  describe("updatePuck", () => {
    it("does nothing when puck is possessed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.possessedBy = 1;
      s.puck.vx = 5;
      const events = updatePuck(s);
      expect(events).toBe(0);
    });

    it("applies friction to free puck", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.vx = 5;
      s.puck.vy = 0;
      updatePuck(s);
      expect(s.puck.vx).toBeLessThan(5);
    });

    it("bounces off top wall", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.y = RINK_TOP + 1;
      s.puck.vy = -3;
      s.puck.vx = 0;
      const events = updatePuck(s);
      expect(s.puck.vy).toBeGreaterThan(0);
      expect(events & EVENT.WALL_BOUNCE).toBeTruthy();
    });

    it("bounces off bottom wall", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.y = RINK_BOTTOM - 1;
      s.puck.vy = 3;
      s.puck.vx = 0;
      const events = updatePuck(s);
      expect(s.puck.vy).toBeLessThan(0);
      expect(events & EVENT.WALL_BOUNCE).toBeTruthy();
    });

    it("bounces off left wall outside goal opening", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = RINK_LEFT + 1;
      s.puck.y = RINK_TOP + 10; // outside goal opening
      s.puck.vx = -3;
      s.puck.vy = 0;
      const events = updatePuck(s);
      expect(s.puck.vx).toBeGreaterThan(0);
      expect(events & EVENT.WALL_BOUNCE).toBeTruthy();
    });

    it("does NOT bounce at goal opening (left)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = RINK_LEFT + 1;
      s.puck.y = RINK_CY; // within goal opening
      s.puck.vx = -3;
      s.puck.vy = 0;
      const events = updatePuck(s);
      expect(s.puck.x).toBeLessThan(RINK_LEFT); // went through
      expect(events & EVENT.WALL_BOUNCE).toBeFalsy();
    });

    it("caps puck speed at maximum", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.vx = 100;
      s.puck.vy = 100;
      updatePuck(s);
      const speed = Math.sqrt(s.puck.vx ** 2 + s.puck.vy ** 2);
      expect(speed).toBeLessThanOrEqual(8.1); // PUCK_SPEED_CAP with small tolerance
    });

    it("stops puck at goal back wall", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = RINK_LEFT - GOAL_DEPTH - 5;
      s.puck.y = RINK_CY;
      s.puck.vx = -5;
      s.puck.vy = 0;
      updatePuck(s);
      expect(s.puck.x).toBeGreaterThanOrEqual(RINK_LEFT - GOAL_DEPTH);
      expect(s.puck.vx).toBe(0);
    });

    it("increments stuck frames when puck is slow", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.vx = 0.1;
      s.puck.vy = 0.1;
      s.puckStuckFrames = 0;
      updatePuck(s);
      expect(s.puckStuckFrames).toBeGreaterThan(0);
    });

    it("resets stuck frames when puck moves fast", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.vx = 3;
      s.puck.vy = 0;
      s.puckStuckFrames = 50;
      updatePuck(s);
      expect(s.puckStuckFrames).toBe(0);
    });

    it("resets NaN velocity to zero (NaN guard)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.vx = NaN;
      s.puck.vy = NaN;
      updatePuck(s);
      expect(Number.isNaN(s.puck.vx)).toBe(false);
      expect(Number.isNaN(s.puck.vy)).toBe(false);
      expect(s.puck.vx).toBe(0);
      expect(s.puck.vy).toBe(0);
    });

    it("resets only NaN component, keeps valid component", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.vx = NaN;
      s.puck.vy = 3;
      updatePuck(s);
      expect(s.puck.vx).toBe(0);
      expect(s.puck.vy).not.toBe(0); // still has velocity (with friction)
    });
  });

  // ── checkCapture ────────────────────────────────────────────

  describe("checkCapture", () => {
    it("captures puck when player is close enough", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = s.p1.x + 5;
      s.puck.y = s.p1.y;
      const events = checkCapture(s);
      expect(events & EVENT.CAPTURE).toBeTruthy();
      expect(s.p1.hasPuck).toBe(true);
      expect(s.puck.possessedBy).toBe(1);
    });

    it("does not capture when too far", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = s.p1.x + 50;
      const events = checkCapture(s);
      expect(events).toBe(0);
      expect(s.p1.hasPuck).toBe(false);
    });

    it("does not capture when puck already possessed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = s.p1.x + 5;
      s.puck.y = s.p1.y;
      s.puck.possessedBy = 2;
      const events = checkCapture(s);
      expect(events).toBe(0);
    });

    it("stunned player cannot capture", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = s.p1.x + 5;
      s.puck.y = s.p1.y;
      s.p1.stunTimer = 5;
      const events = checkCapture(s);
      expect(events).toBe(0);
      expect(s.p1.hasPuck).toBe(false);
    });

    it("resets puck stuck frames on capture", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = s.p1.x + 5;
      s.puck.y = s.p1.y;
      s.puckStuckFrames = 100;
      checkCapture(s);
      expect(s.puckStuckFrames).toBe(0);
    });

    it("P2 can capture too", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = s.p2.x + 3;
      s.puck.y = s.p2.y;
      checkCapture(s);
      expect(s.p2.hasPuck).toBe(true);
      expect(s.puck.possessedBy).toBe(2);
    });
  });

  // ── checkGoalieBlock ────────────────────────────────────────

  describe("checkGoalieBlock", () => {
    it("blocks when puck hits goalie hitbox", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const { g1x } = getGoalieXPositions(s);
      s.puck.x = g1x;
      s.puck.y = s.g1.y;
      s.puck.vx = -3;
      s.puck.vy = 0;
      const events = checkGoalieBlock(s);
      expect(events & EVENT.GOALIE_BLOCK).toBeTruthy();
    });

    it("does not block when puck is slow", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const { g1x } = getGoalieXPositions(s);
      s.puck.x = g1x;
      s.puck.y = s.g1.y;
      s.puck.vx = 0.1;
      s.puck.vy = 0;
      const events = checkGoalieBlock(s);
      expect(events).toBe(0);
    });

    it("does not block when puck is possessed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.possessedBy = 1;
      const events = checkGoalieBlock(s);
      expect(events).toBe(0);
    });

    it("reflects puck velocity after block", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const { g1x } = getGoalieXPositions(s);
      s.puck.x = g1x + 1;
      s.puck.y = s.g1.y;
      s.puck.vx = -5;
      s.puck.vy = 0;
      checkGoalieBlock(s);
      // Puck should now be moving away from goalie
      expect(s.puck.vx).toBeGreaterThan(0);
    });
  });

  // ── handleShoot ─────────────────────────────────────────────

  describe("handleShoot", () => {
    it("releases puck with velocity in facing direction", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.hasPuck = true;
      s.p1.facing = 0; // right
      s.puck.possessedBy = 1;
      const events = handleShoot(s, true);
      expect(events & EVENT.SHOT).toBeTruthy();
      expect(s.p1.hasPuck).toBe(false);
      expect(s.puck.possessedBy).toBe(0);
      expect(s.puck.vx).toBeGreaterThan(0);
    });

    it("does nothing if player has no puck", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      const events = handleShoot(s, true);
      expect(events).toBe(0);
    });

    it("does nothing if player is stunned", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.hasPuck = true;
      s.p1.stunTimer = 5;
      const events = handleShoot(s, true);
      expect(events).toBe(0);
    });

    it("shot speed is faster in BLITZ mode", () => {
      const sClassic = createInitialState(GAME_MODE.CLASSIC);
      sClassic.p1.hasPuck = true;
      sClassic.p1.facing = 0;
      sClassic.puck.possessedBy = 1;
      handleShoot(sClassic, true);
      const classicSpeed = Math.abs(sClassic.puck.vx);

      const sBlitz = createInitialState(GAME_MODE.BLITZ);
      sBlitz.p1.hasPuck = true;
      sBlitz.p1.facing = 0;
      sBlitz.puck.possessedBy = 1;
      handleShoot(sBlitz, true);
      const blitzSpeed = Math.abs(sBlitz.puck.vx);

      expect(blitzSpeed).toBeGreaterThan(classicSpeed);
    });

    it("SHOWDOWN speed increases with goals scored", () => {
      const s1 = createInitialState(GAME_MODE.SHOWDOWN);
      s1.p1.hasPuck = true;
      s1.p1.facing = 0;
      s1.puck.possessedBy = 1;
      s1.scoreP1 = 0;
      s1.scoreP2 = 0;
      handleShoot(s1, true);
      const earlySpeed = Math.abs(s1.puck.vx);

      const s2 = createInitialState(GAME_MODE.SHOWDOWN);
      s2.p1.hasPuck = true;
      s2.p1.facing = 0;
      s2.puck.possessedBy = 1;
      s2.scoreP1 = 3;
      s2.scoreP2 = 3;
      handleShoot(s2, true);
      const lateSpeed = Math.abs(s2.puck.vx);

      expect(lateSpeed).toBeGreaterThan(earlySpeed);
    });
  });

  // ── handleTackle ────────────────────────────────────────────

  describe("handleTackle", () => {
    it("cannot tackle if attacker has puck", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.hasPuck = true;
      const events = handleTackle(s, true);
      expect(events).toBe(0);
    });

    it("cannot tackle if attacker is stunned", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p2.hasPuck = true;
      s.p1.stunTimer = 5;
      s.p1.x = s.p2.x + 5;
      s.p1.y = s.p2.y;
      const events = handleTackle(s, true);
      expect(events).toBe(0);
    });

    it("cannot tackle if defender has no puck", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.x = s.p2.x + 5;
      s.p1.y = s.p2.y;
      const events = handleTackle(s, true);
      expect(events).toBe(0);
    });

    it("cannot tackle if too far away", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p2.hasPuck = true;
      // Players start 120px apart
      const events = handleTackle(s, true);
      expect(events).toBe(0);
    });

    it("tackle within range succeeds or fails", () => {
      // Run many times to get both outcomes
      let successes = 0;
      let failures = 0;

      for (let i = 0; i < 100; i++) {
        const s = createInitialState(GAME_MODE.CLASSIC);
        s.p2.hasPuck = true;
        s.puck.possessedBy = 2;
        s.p1.x = s.p2.x + 10;
        s.p1.y = s.p2.y;

        const events = handleTackle(s, true);
        if (events & EVENT.TACKLE_SUCCESS) {
          successes++;
          expect(s.p2.hasPuck).toBe(false);
          expect(s.puck.possessedBy).toBe(0);
        } else if (events & EVENT.TACKLE_FAIL) {
          failures++;
          expect(s.p1.stunTimer).toBe(STUN_DURATION);
          expect(s.p2.hasPuck).toBe(true);
        }
      }

      // With 60% success rate over 100 tries, both should happen
      expect(successes).toBeGreaterThan(0);
      expect(failures).toBeGreaterThan(0);
    });

    it("BLITZ mode has higher tackle success rate", () => {
      let blitzSuccesses = 0;
      let classicSuccesses = 0;

      for (let i = 0; i < 200; i++) {
        const sBlitz = createInitialState(GAME_MODE.BLITZ);
        sBlitz.p2.hasPuck = true;
        sBlitz.puck.possessedBy = 2;
        sBlitz.p1.x = sBlitz.p2.x + 10;
        sBlitz.p1.y = sBlitz.p2.y;
        if (handleTackle(sBlitz, true) & EVENT.TACKLE_SUCCESS) blitzSuccesses++;

        const sClassic = createInitialState(GAME_MODE.CLASSIC);
        sClassic.p2.hasPuck = true;
        sClassic.puck.possessedBy = 2;
        sClassic.p1.x = sClassic.p2.x + 10;
        sClassic.p1.y = sClassic.p2.y;
        if (handleTackle(sClassic, true) & EVENT.TACKLE_SUCCESS) classicSuccesses++;
      }

      // Blitz 80% vs Classic 60% — blitz should win with high confidence
      expect(blitzSuccesses).toBeGreaterThan(classicSuccesses);
    });
  });

  // ── checkGoal ───────────────────────────────────────────────

  describe("checkGoal", () => {
    it("detects goal on left side (P2 scores when P1 defends left)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = GOAL_LINE_LEFT - PUCK_R - 1;
      s.puck.y = RINK_CY;
      const result = checkGoal(s);
      expect(result).toBe("p2"); // P2 scored on P1's goal
    });

    it("detects goal on right side (P1 scores when P2 defends right)", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = GOAL_LINE_RIGHT + PUCK_R + 1;
      s.puck.y = RINK_CY;
      const result = checkGoal(s);
      expect(result).toBe("p1");
    });

    it("no goal if puck outside goal opening vertically", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = GOAL_LINE_LEFT - PUCK_R - 1;
      s.puck.y = RINK_TOP + 5; // above goal opening
      expect(checkGoal(s)).toBeNull();
    });

    it("no goal if puck is possessed", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = GOAL_LINE_LEFT - PUCK_R - 1;
      s.puck.y = RINK_CY;
      s.puck.possessedBy = 1;
      expect(checkGoal(s)).toBeNull();
    });

    it("respects sidesSwapped for goal attribution", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.sidesSwapped = true;
      // When swapped, P2 defends left, P1 defends right
      s.puck.x = GOAL_LINE_LEFT - PUCK_R - 1;
      s.puck.y = RINK_CY;
      expect(checkGoal(s)).toBe("p1"); // P1 scored on P2's left goal
    });

    it("no goal if puck is between goal lines", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puck.x = RINK_CX;
      s.puck.y = RINK_CY;
      expect(checkGoal(s)).toBeNull();
    });
  });

  // ── checkPuckStuck ──────────────────────────────────────────

  describe("checkPuckStuck", () => {
    it("returns true when stuck frames exceed threshold", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puckStuckFrames = 300;
      expect(checkPuckStuck(s)).toBe(true);
    });

    it("returns false below threshold", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.puckStuckFrames = 100;
      expect(checkPuckStuck(s)).toBe(false);
    });
  });

  // ── advancePeriod ───────────────────────────────────────────

  describe("advancePeriod", () => {
    it("advances to next period in CLASSIC mode", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.period = 1;
      s.scoreP1 = 1;
      s.scoreP2 = 0;
      const events = advancePeriod(s);
      expect(s.period).toBe(2);
      expect(s.phase).toBe(PHASE.PERIOD_BREAK);
      expect(events & EVENT.PERIOD_END).toBeTruthy();
    });

    it("swaps sides after each period", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.period = 1;
      s.sidesSwapped = false;
      advancePeriod(s);
      expect(s.sidesSwapped).toBe(true);
    });

    it("finishes game after 3 periods with clear winner", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.period = 3;
      s.scoreP1 = 3;
      s.scoreP2 = 1;
      advancePeriod(s);
      expect(s.phase).toBe(PHASE.FINISHED);
    });

    it("enters sudden death after 3 tied periods", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.period = 3;
      s.scoreP1 = 2;
      s.scoreP2 = 2;
      const events = advancePeriod(s);
      expect(s.period).toBe(4);
      expect(s.timerFrames).toBe(0);
      expect(events & EVENT.SUDDEN_DEATH).toBeTruthy();
    });

    it("enters sudden death after 1 tied period in BLITZ", () => {
      const s = createInitialState(GAME_MODE.BLITZ);
      s.period = 1;
      s.scoreP1 = 1;
      s.scoreP2 = 1;
      const events = advancePeriod(s);
      expect(s.period).toBe(2);
      expect(s.timerFrames).toBe(0);
      expect(events & EVENT.SUDDEN_DEATH).toBeTruthy();
    });

    it("does nothing for SHOWDOWN mode", () => {
      const s = createInitialState(GAME_MODE.SHOWDOWN);
      const events = advancePeriod(s);
      expect(events).toBe(0);
    });

    it("resets positions after period advance", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.period = 1;
      s.p1.x = 100;
      advancePeriod(s);
      expect(s.puck.x).toBe(RINK_CX);
    });
  });

  // ── checkShowdownWin ────────────────────────────────────────

  describe("checkShowdownWin", () => {
    it("returns true when P1 reaches target", () => {
      const s = createInitialState(GAME_MODE.SHOWDOWN);
      s.scoreP1 = SHOWDOWN_TARGET;
      expect(checkShowdownWin(s)).toBe(true);
    });

    it("returns true when P2 reaches target", () => {
      const s = createInitialState(GAME_MODE.SHOWDOWN);
      s.scoreP2 = SHOWDOWN_TARGET;
      expect(checkShowdownWin(s)).toBe(true);
    });

    it("returns false below target", () => {
      const s = createInitialState(GAME_MODE.SHOWDOWN);
      s.scoreP1 = SHOWDOWN_TARGET - 1;
      s.scoreP2 = SHOWDOWN_TARGET - 1;
      expect(checkShowdownWin(s)).toBe(false);
    });

    it("returns false for non-SHOWDOWN modes", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.scoreP1 = 10;
      expect(checkShowdownWin(s)).toBe(false);
    });
  });

  // ── determineWinner ─────────────────────────────────────────

  describe("determineWinner", () => {
    it("P1 wins with higher score", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.scoreP1 = 3;
      s.scoreP2 = 1;
      const result = determineWinner(s);
      expect(result.winner).toBe("p1");
      expect(result.score_p1).toBe(3);
      expect(result.score_p2).toBe(1);
    });

    it("P2 wins with higher score", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.scoreP1 = 0;
      s.scoreP2 = 2;
      expect(determineWinner(s).winner).toBe("p2");
    });

    it("draw with equal scores", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.scoreP1 = 1;
      s.scoreP2 = 1;
      expect(determineWinner(s).winner).toBe("draw");
    });

    it("includes period and mode info", () => {
      const s = createInitialState(GAME_MODE.BLITZ);
      s.period = 2;
      s.scoreP1 = 1;
      s.scoreP2 = 0;
      const result = determineWinner(s);
      expect(result.periods).toBe(2);
      expect(result.mode).toBe(GAME_MODE.BLITZ);
    });
  });

  // ── packState / unpackState ─────────────────────────────────

  describe("packState / unpackState", () => {
    it("roundtrips full state for rendering", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.x = 150.7;
      s.p1.y = 200.3;
      s.p1.facing = 5;
      s.p1.hasPuck = true;
      s.p1.stunTimer = 8;
      s.scoreP1 = 2;
      s.scoreP2 = 3;
      s.period = 2;
      s.sidesSwapped = true;

      const packed = packState(s);
      const unpacked = unpackState(packed);

      expect(unpacked.p1.x).toBe(Math.round(s.p1.x));
      expect(unpacked.p1.y).toBe(Math.round(s.p1.y));
      expect(unpacked.p1.facing).toBe(5);
      expect(unpacked.p1.hasPuck).toBe(true);
      expect(unpacked.p1.stunTimer).toBe(8);
      expect(unpacked.scoreP1).toBe(2);
      expect(unpacked.scoreP2).toBe(3);
      expect(unpacked.period).toBe(2);
      expect(unpacked.sidesSwapped).toBe(true);
    });

    it("rounds positions to integers", () => {
      const s = createInitialState(GAME_MODE.CLASSIC);
      s.p1.x = 123.456;
      const packed = packState(s);
      expect(packed.p1x).toBe(123);
    });
  });

  // ── Constants ───────────────────────────────────────────────

  describe("constants", () => {
    it("COUNTDOWN_FRAME_INTERVAL is 60 (1 second at 60fps)", () => {
      expect(COUNTDOWN_FRAME_INTERVAL).toBe(60);
    });

    it("GOAL_CELEBRATION_FRAMES is 120 (2 seconds at 60fps)", () => {
      expect(GOAL_CELEBRATION_FRAMES).toBe(120);
    });

    it("SHOWDOWN_TARGET is 5", () => {
      expect(SHOWDOWN_TARGET).toBe(5);
    });

    it("rink geometry is consistent", () => {
      expect(RINK_LEFT).toBeLessThan(RINK_RIGHT);
      expect(RINK_TOP).toBeLessThan(RINK_BOTTOM);
      expect(RINK_CX).toBe((RINK_LEFT + RINK_RIGHT) / 2);
      expect(RINK_CY).toBe((RINK_TOP + RINK_BOTTOM) / 2);
    });

    it("goal opening is within rink height", () => {
      expect(GOAL_TOP).toBeGreaterThan(RINK_TOP);
      expect(GOAL_BOTTOM).toBeLessThan(RINK_BOTTOM);
    });
  });
});
