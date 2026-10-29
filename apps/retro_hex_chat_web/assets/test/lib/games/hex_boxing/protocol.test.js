import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  PUNCH_STATE,
  encodeGameReady,
  getMessageType,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/hex_boxing/protocol.js";
import {
  describeMatchMessages,
  itFramesMessages,
  itRoundTripsEach,
  roundTrip,
} from "../../../support/games/protocol_tests.js";

describe("Hex Boxing Protocol", () => {
  function makeState(overrides) {
    return {
      b1x: 200,
      b1y: 240,
      b1dir: 0,
      b1punchState: PUNCH_STATE.IDLE,
      b1arm: 0,
      b1punchTimer: 0,
      b2x: 440,
      b2y: 240,
      b2dir: 4,
      b2punchState: PUNCH_STATE.IDLE,
      b2arm: 0,
      b2punchTimer: 0,
      score1: 0,
      score2: 0,
      phase: PHASE.WAITING,
      countdown: 0,
      round: 1,
      roundWins1: 0,
      roundWins2: 0,
      roundTimer: 7200,
      lastHitPlayer: 0,
      lastHitPoints: 0,
      ...overrides,
    };
  }

  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = makeState({
        b1punchState: PUNCH_STATE.PUNCHING,
        b1arm: 1,
        b1punchTimer: 5,
        b2y: 200,
        b2punchState: PUNCH_STATE.COOLDOWN,
        b2punchTimer: 3,
        score1: 47,
        score2: 32,
        phase: PHASE.FIGHTING,
        round: 2,
        roundWins1: 1,
        roundTimer: 3600,
        lastHitPlayer: 1,
        lastHitPoints: 3,
      });

      expect(roundTrip(SNAPSHOT, state)).toEqual(state);
    });

    itFramesMessages(SNAPSHOT, {
      sample: makeState(),
      bytes: 26,
      type: MSG_TYPE.GAME_STATE,
      short: [10],
      length: 26,
      wrongType: 0x81,
    });

    it("encodes all boxer flag combinations", () => {
      for (const b1punchState of Object.values(PUNCH_STATE)) {
        for (const b1arm of [0, 1]) {
          const state = makeState({ b1punchState, b1arm });
          expect(roundTrip(SNAPSHOT, state)).toMatchObject({ b1punchState, b1arm });
        }
      }
    });

    itRoundTripsEach(SNAPSHOT, makeState, {
      score1: [0, 99, 100],
      b1dir: [0, 1, 2, 3, 4, 5, 6, 7],
      phase: Object.values(PHASE),
      roundTimer: [0, 3600, 65535],
      b1punchTimer: [0, 255],
      lastHitPlayer: [0, 1, 2],
      lastHitPoints: [0, 1, 2, 3],
      b1x: [0, 640],
      b2y: [0, 480],
    });

    it("rounds float positions to nearest integer", () => {
      expect(roundTrip(SNAPSHOT, makeState({ b1x: 200.7, b1y: 240.3 }))).toMatchObject({
        b1x: 201,
        b1y: 240,
      });
    });

    it("does not transmit cooldownTimer (internal-only field)", () => {
      const decoded = roundTrip(SNAPSHOT, makeState({ b1cooldownTimer: 5, b2cooldownTimer: 5 }));
      expect(decoded.b1cooldownTimer).toBeUndefined();
      expect(decoded.b2cooldownTimer).toBeUndefined();
    });
  });

  describeMatchMessages(
    { GAME_END, MSG_TYPE, encodeGameReady, getMessageType },
    { score1: 100, score2: 47, winner: 1, roundWins1: 2, roundWins2: 1 },
  );
});
