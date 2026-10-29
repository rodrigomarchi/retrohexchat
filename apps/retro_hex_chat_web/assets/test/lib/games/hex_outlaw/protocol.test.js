import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  encodeGameReady,
  getMessageType,
  SNAPSHOT,
  GAME_END,
} from "../../../../js/lib/games/hex_outlaw/protocol.js";
import { describeMatchMessages, itFramesMessages } from "../../../support/games/protocol_tests.js";

import { BULLET_SPEED_X, createInitialState } from "../../../../js/lib/games/hex_outlaw/physics.js";
import { inFlight } from "./in_flight.js";

describe("Hex Outlaw Protocol", () => {
  /** A street at the start of play, both gunslingers and the obstacle on line 240. */
  function makeState(overrides) {
    const start = createInitialState(GAME_MODE.QUICK_DRAW);
    return { ...start, p1y: 240, p2y: 240, obsY: 240, ...overrides };
  }

  describe("game state encode/decode", () => {
    it("roundtrips a full state", () => {
      const state = makeState({
        p1x: 80,
        p1y: 150,
        p1shooting: true,
        p2x: 560,
        p2y: 300,
        p2shooting: false,
        score1: 5,
        score2: 3,
        phase: PHASE.PLAYING,
        round: 2,
        roundWins1: 1,
        gameMode: GAME_MODE.QUICK_DRAW,
      });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded).not.toBeNull();
      expect(decoded.p1x).toBe(80);
      expect(decoded.p1y).toBe(150);
      expect(decoded.p1shooting).toBe(true);
      expect(decoded.p2x).toBe(560);
      expect(decoded.p2y).toBe(300);
      expect(decoded.p2shooting).toBe(false);
      expect(decoded.score1).toBe(5);
      expect(decoded.score2).toBe(3);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.round).toBe(2);
      expect(decoded.roundWins1).toBe(1);
    });

    it("roundtrips bullet state when active", () => {
      const state = makeState({
        ...inFlight("b1", { x: 200, y: 150 }),
      });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.b1active).toBe(true);
      expect(decoded.b1x).toBe(200);
      expect(decoded.b1y).toBe(150);
      expect(decoded.b1vx).toBe(BULLET_SPEED_X);
      expect(decoded.b1vy).toBe(0);
      expect(decoded.b1bounced).toBe(false);
    });

    it("roundtrips bullet with negative vx", () => {
      const state = makeState({
        ...inFlight("b2", { x: 400, y: 200 }),
      });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.b2vx).toBe(-BULLET_SPEED_X);
      expect(decoded.b2active).toBe(true);
    });

    it("roundtrips bullet with vy (ricochet)", () => {
      const vy = BULLET_SPEED_X * Math.sin(Math.PI / 6);
      const state = makeState({
        ...inFlight("b1", { x: 200, y: 200, vy: vy }),
      });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.b1vy).toBeCloseTo(vy, 1);
      expect(decoded.b1bounced).toBe(false);
    });

    it("roundtrips bounced flag", () => {
      const state = makeState({
        ...inFlight("b1", { x: 200, y: 200, vy: -4, bounced: true }),
      });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.b1bounced).toBe(true);
    });

    it("roundtrips all game modes", () => {
      for (const mode of [
        GAME_MODE.QUICK_DRAW,
        GAME_MODE.RICOCHET,
        GAME_MODE.STAGECOACH,
        GAME_MODE.NO_MANS_LAND,
      ]) {
        const state = makeState({ gameMode: mode });
        const buf = SNAPSHOT.encode(state);
        const decoded = SNAPSHOT.decode(buf);
        expect(decoded.gameMode).toBe(mode);
      }
    });

    it("roundtrips obstacle position", () => {
      const state = makeState({ obsY: 300, obsDir: 255 });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.obsY).toBe(300);
      expect(decoded.obsDir).toBe(255);
    });

    it("roundtrips hit pause state", () => {
      const state = makeState({
        phase: PHASE.HIT_PAUSE,
        hitPauseTimer: 45,
        lastHitPlayer: 1,
      });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.phase).toBe(PHASE.HIT_PAUSE);
      expect(decoded.hitPauseTimer).toBe(45);
      expect(decoded.lastHitPlayer).toBe(1);
    });

    itFramesMessages(SNAPSHOT, { short: [5], length: 38, wrongType: 0x81 });

    it("inactive bullets decode correctly", () => {
      const state = makeState({ b1active: false, b2active: false });
      const buf = SNAPSHOT.encode(state);
      const decoded = SNAPSHOT.decode(buf);
      expect(decoded.b1active).toBe(false);
      expect(decoded.b2active).toBe(false);
    });
  });

  describeMatchMessages(
    { GAME_END, MSG_TYPE, encodeGameReady, getMessageType },
    { score1: 10, score2: 7, winner: 1, roundWins1: 2, roundWins2: 1 },
  );
});
