import { describe, it, expect } from "vitest";
import { PHASE } from "../../../../js/lib/games/warlords/protocol.js";
import {
  CANVAS_H,
  SHIELD_H,
  SHIELD_SPEED,
  createInitialState,
  stepTick,
} from "../../../../js/lib/games/warlords/physics.js";

describe("warlords physics", () => {
  describe("stepTick", () => {
    const still = { up: false, down: false, space: false };

    it("moves both shields by their keys and the fireball by its velocity", () => {
      const s = { ...createInitialState(), phase: PHASE.PLAYING, fireballVX: 3, fireballVY: 2 };
      const { state, events } = stepTick(s, { ...still, up: true }, { ...still, down: true });

      expect(state.shield1Y).toBe(s.shield1Y - SHIELD_SPEED);
      expect(state.shield2Y).toBe(s.shield2Y + SHIELD_SPEED);
      expect(state.fireballX).toBe(s.fireballX + 3);
      expect(state.fireballY).toBe(s.fireballY + 2);
      expect(events).toEqual({
        wallBounced: false,
        shieldHit: false,
        caught: false,
        brickHit: false,
        kingHit: false,
      });
    });

    it("reports a wall bounce beside the state, with the flag down", () => {
      const s = {
        ...createInitialState(),
        phase: PHASE.PLAYING,
        fireballY: CANVAS_H - 3,
        fireballVX: 3,
        fireballVY: 4,
      };
      const { state, events } = stepTick(s, still, still);

      expect(events.wallBounced).toBe(true);
      expect(state.wallBounced).toBe(false);
      expect(state.fireballVY).toBeLessThan(0);
      expect(state.shield1Y + SHIELD_H).toBeLessThanOrEqual(CANVAS_H);
    });
  });
});
