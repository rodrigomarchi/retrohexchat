import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  encodeGameReady,
  getMessageType,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/pixel_tanks/protocol.js";
import {
  describeMatchMessages,
  expectCloseAfterRoundTrip,
  itFramesMessages,
  itRoundTripsEach,
  roundTrip,
} from "../../../support/games/protocol_tests.js";

/** A snapshot with everything zeroed, but for `overrides`. */
function makeState(overrides = {}) {
  return {
    tank1X: 0,
    tank1Y: 0,
    tank1Rot: 0,
    tank1Alive: false,
    tank1Invuln: false,
    tank2X: 0,
    tank2Y: 0,
    tank2Rot: 0,
    tank2Alive: false,
    tank2Invuln: false,
    m1X: 0,
    m1Y: 0,
    m1VX: 0,
    m1VY: 0,
    m1Active: false,
    m1Bounced: false,
    m2X: 0,
    m2Y: 0,
    m2VX: 0,
    m2VY: 0,
    m2Active: false,
    m2Bounced: false,
    score1: 0,
    score2: 0,
    phase: 0,
    countdown: 0,
    mode: 0,
    mazeIndex: 0,
    round: 1,
    roundWins1: 0,
    roundWins2: 0,
    roundTimer: 0,
    ...overrides,
  };
}

describe("Pixel Tanks Protocol", () => {
  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = makeState({
        tank1X: 48.5,
        tank1Y: 240.25,
        tank1Rot: 1.5708,
        tank1Alive: true,
        tank2X: 592.0,
        tank2Y: 240.0,
        tank2Rot: 3.1416,
        tank2Alive: true,
        tank2Invuln: true,
        m1X: 100.0,
        m1Y: 200.0,
        m1VX: 5.0,
        m1VY: 0.0,
        m1Active: true,
        m2X: 400.0,
        m2Y: 300.0,
        m2VX: -3.0,
        m2VY: 4.0,
        m2Active: true,
        m2Bounced: true,
        score1: 3,
        score2: 5,
        phase: PHASE.PLAYING,
        mode: GAME_MODE.MAZE_BATTLE,
        mazeIndex: 2,
        round: 2,
        roundWins1: 1,
        roundTimer: 3600,
      });

      const floats = ["tank1X", "tank1Y", "tank2X", "tank2Y", "m1X", "m1Y", "m2X", "m2Y"];
      const rotations = ["tank1Rot", "tank2Rot"];
      const exact = Object.fromEntries(
        Object.entries(state).filter(([key]) => ![...floats, ...rotations].includes(key)),
      );

      expectCloseAfterRoundTrip(SNAPSHOT, state, floats);
      expect(roundTrip(SNAPSHOT, state)).toMatchObject(exact);
      // Rotation is encoded as Uint16 * 10000, some precision loss
      expect(roundTrip(SNAPSHOT, state).tank1Rot).toBeCloseTo(1.5708, 2);
    });

    itFramesMessages(SNAPSHOT, {
      sample: makeState({ roundTimer: 7200 }),
      bytes: 68,
      type: MSG_TYPE.GAME_STATE,
      short: [10],
      length: 68,
      wrongType: 0x81,
    });
  });

  describeMatchMessages(
    { GAME_END, MSG_TYPE, encodeGameReady, getMessageType },
    { score1: 7, score2: 3, winner: 1, roundWins1: 2, roundWins2: 1 },
  );

  describe("boundary values", () => {
    it("keeps rotation from 0 to just under 2*PI", () => {
      expectCloseAfterRoundTrip(SNAPSHOT, makeState({ tank1Rot: 6.2831 }), ["tank1Rot"]);
      expect(roundTrip(SNAPSHOT, makeState({ tank1Rot: 0 })).tank1Rot).toBeCloseTo(0, 2);
    });

    it("handles negative coordinates", () => {
      expectCloseAfterRoundTrip(SNAPSHOT, makeState({ tank1X: -50.5, tank1Y: -100.25 }), [
        "tank1X",
        "tank1Y",
      ]);
    });

    it("handles all flag combinations for a tank and a missile", () => {
      for (const one of [true, false]) {
        for (const two of [true, false]) {
          const flags = { tank1Alive: one, tank1Invuln: two, m1Active: one, m1Bounced: two };
          expect(roundTrip(SNAPSHOT, makeState(flags))).toMatchObject(flags);
        }
      }
    });

    itRoundTripsEach(SNAPSHOT, makeState, {
      score1: [0, 3, 255],
      score2: [0, 5, 255],
      roundTimer: [0, 3600, 7200, 65535],
      phase: Object.values(PHASE),
      mode: Object.values(GAME_MODE),
    });
  });
});
