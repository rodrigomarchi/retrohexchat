import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  SNAPSHOT,
  GAME_END,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/pong/protocol.js";
import {
  describeHandshake,
  expectCloseAfterRoundTrip,
  expectGameMessageRange,
  expectNumbered,
  itFramesMessages,
  itRoundTripsEach,
  roundTrip,
} from "../../../support/games/protocol_tests.js";

/** A snapshot with every field zero, but for `overrides`. */
function makeState(overrides = {}) {
  return {
    ballX: 0,
    ballY: 0,
    ballVX: 0,
    ballVY: 0,
    paddle1Y: 0,
    paddle2Y: 0,
    score1: 0,
    score2: 0,
    phase: PHASE.WAITING,
    countdown: 0,
    ...overrides,
  };
}

describe("pong_protocol", () => {
  describe("GAME_STATE encode/decode", () => {
    it("roundtrips a full game state", () => {
      const state = makeState({
        ballX: 320.5,
        ballY: 240.25,
        ballVX: 4.5,
        ballVY: -2.75,
        paddle1Y: 200,
        paddle2Y: 180,
        score1: 7,
        score2: 11,
        phase: PHASE.PLAYING,
      });

      const buf = SNAPSHOT.encode(state);
      expect(buf.byteLength).toBe(25);

      expect(SNAPSHOT.decode(buf)).toMatchObject({
        ballX: expect.closeTo(320.5, 1),
        ballY: expect.closeTo(240.25, 1),
        ballVX: expect.closeTo(4.5, 1),
        ballVY: expect.closeTo(-2.75, 1),
        paddle1Y: 200,
        paddle2Y: 180,
        score1: 7,
        score2: 11,
        phase: PHASE.PLAYING,
        countdown: 0,
      });
    });

    itFramesMessages(SNAPSHOT, {
      sample: makeState(),
      bytes: 25,
      type: 0x80,
      short: [24, 0],
      length: 25,
      wrongType: 0x81,
    });

    it("rounds paddle positions to nearest integer", () => {
      const decoded = roundTrip(SNAPSHOT, makeState({ paddle1Y: 199.7, paddle2Y: 300.3 }));
      expect(decoded.paddle1Y).toBe(200);
      expect(decoded.paddle2Y).toBe(300);
    });

    it("handles max paddle Y (480)", () => {
      expect(roundTrip(SNAPSHOT, makeState({ paddle1Y: 480 })).paddle1Y).toBe(480);
    });

    itRoundTripsEach(SNAPSHOT, makeState, {
      phase: Object.values(PHASE),
      countdown: { values: [0, 1, 2, 3], with: { phase: PHASE.COUNTDOWN } },
    });

    it("handles negative ball velocities", () => {
      const state = makeState({ ballX: 100, ballY: 200, ballVX: -5.5, ballVY: -3.25 });
      expectCloseAfterRoundTrip(SNAPSHOT, state, ["ballVX", "ballVY"]);
    });
  });

  describe("GAME_END encode/decode", () => {
    it("roundtrips a game end", () => {
      const buf = GAME_END.encode({ score1: 11, score2: 7, winner: 1 });
      expect(buf.byteLength).toBe(4);
      expect(GAME_END.decode(buf)).toMatchObject({ score1: 11, score2: 7, winner: 1 });
    });

    it("roundtrips player 2 win", () => {
      const end = { score1: 9, score2: 11, winner: 2 };
      expect(roundTrip(GAME_END, end)).toMatchObject(end);
    });

    itFramesMessages(GAME_END, {
      sample: { score1: 0, score2: 0, winner: 1 },
      type: 0x83,
      short: [3],
      length: 4,
      wrongType: 0x80,
    });
  });

  describeHandshake({ encodeGameReady, getMessageType, MSG_TYPE });

  describe("protocol constants", () => {
    it("all message types are >= 0x80 (game message range)", () => {
      expectGameMessageRange(MSG_TYPE);
    });

    it("phase enum has 6 values (0-5)", () => {
      expectNumbered(PHASE, 6);
      expect(PHASE.FINISHED).toBe(5);
    });
  });
});
