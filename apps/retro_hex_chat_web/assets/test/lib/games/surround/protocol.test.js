import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  DIR,
  INPUT_KEY,
  GRID_W,
  GRID_H,
  WINS_NEEDED,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/surround/protocol.js";
import * as protocol from "../../../../js/lib/games/surround/protocol.js";
import {
  describeHandshake,
  itFramesMessages,
  roundTrip,
} from "../../../support/games/protocol_tests.js";

/** A round under way, with `overrides` over it. */
function makeState(overrides = {}) {
  return {
    p1: { x: 5, y: 20, dir: DIR.RIGHT },
    p2: { x: 54, y: 20, dir: DIR.LEFT },
    score1: 2,
    score2: 1,
    phase: PHASE.PLAYING,
    countdown: 0,
    round: 2,
    ...overrides,
  };
}

describe("surround_protocol", () => {
  describe("encodeGameState / decodeGameState", () => {
    it("round-trips game state correctly", () => {
      const state = makeState();
      const decoded = roundTrip(SNAPSHOT, state);

      expect(decoded.p1x).toBe(state.p1.x);
      expect(decoded.p1y).toBe(state.p1.y);
      expect(decoded.p1dir).toBe(state.p1.dir);
      expect(decoded.p2x).toBe(state.p2.x);
      expect(decoded.p2y).toBe(state.p2.y);
      expect(decoded.p2dir).toBe(state.p2.dir);
      expect(decoded.score1).toBe(state.score1);
      expect(decoded.score2).toBe(state.score2);
      expect(decoded.phase).toBe(state.phase);
      expect(decoded.countdown).toBe(state.countdown);
      expect(decoded.round).toBe(state.round);
    });

    itFramesMessages(SNAPSHOT, {
      sample: makeState(),
      bytes: 12,
      type: MSG_TYPE.GAME_STATE,
      short: [5],
      length: 12,
      wrongType: 0x81,
    });

    it("round-trips zero values and max positions", () => {
      const decoded = roundTrip(
        SNAPSHOT,
        makeState({
          p1: { x: 0, y: 0, dir: DIR.UP },
          p2: { x: GRID_W - 1, y: GRID_H - 1, dir: DIR.DOWN },
          phase: PHASE.WAITING,
          countdown: 3,
        }),
      );
      expect(decoded.p1x).toBe(0);
      expect(decoded.p1y).toBe(0);
      expect(decoded.p2x).toBe(GRID_W - 1);
      expect(decoded.p2y).toBe(GRID_H - 1);
      expect(decoded.countdown).toBe(3);
    });

    it.each(Object.values(DIR))("round-trips direction %i", (dir) => {
      const decoded = roundTrip(
        SNAPSHOT,
        makeState({ p1: { x: 10, y: 10, dir }, p2: { x: 20, y: 20, dir } }),
      );
      expect(decoded.p1dir).toBe(dir);
      expect(decoded.p2dir).toBe(dir);
    });

    it.each(Object.values(PHASE))("round-trips phase %i", (phase) => {
      expect(roundTrip(SNAPSHOT, makeState({ phase })).phase).toBe(phase);
    });
  });

  describe("encodeGameEnd / decodeGameEnd", () => {
    it.each([
      ["P1 wins", { score1: 3, score2: 1, winner: 1 }],
      ["P2 wins", { score1: 2, score2: 3, winner: 2 }],
      ["a draw", { score1: 0, score2: 0, winner: 0 }],
    ])("round-trips %s", (_name, result) => {
      expect(roundTrip(GAME_END, result)).toEqual(result);
    });

    itFramesMessages(GAME_END, {
      sample: { score1: 3, score2: 2, winner: 1 },
      type: MSG_TYPE.GAME_END,
      short: [2],
      length: 4,
      wrongType: 0x81,
    });
  });

  describe("round overflow", () => {
    it.each([
      [256, 0],
      [257, 1],
    ])("encodes round %i as %i, in uint8 range", (round, wired) => {
      expect(roundTrip(SNAPSHOT, makeState({ round })).round).toBe(wired);
    });
  });

  describeHandshake(protocol);

  describe("constants", () => {
    it("has 60x40 grid", () => {
      expect(GRID_W).toBe(60);
      expect(GRID_H).toBe(40);
    });

    it("needs 3 wins", () => {
      expect(WINS_NEEDED).toBe(3);
    });

    it("has 5 phases", () => {
      expect(Object.keys(PHASE)).toHaveLength(5);
    });

    it("has 4 directions", () => {
      expect(Object.keys(DIR)).toHaveLength(4);
    });

    it("has 4 input keys", () => {
      expect(Object.keys(INPUT_KEY)).toHaveLength(4);
    });
  });
});
