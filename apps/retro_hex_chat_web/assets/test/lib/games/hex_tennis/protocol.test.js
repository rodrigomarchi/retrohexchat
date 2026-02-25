import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  ANNOUNCEMENT,
  OUT_TYPE,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/hex_tennis/protocol.js";

function makeState(overrides = {}) {
  return {
    p1x: 320,
    p1y: 410,
    p2x: 320,
    p2y: 70,
    ballX: 320,
    ballY: 240,
    ballVX: 0,
    ballVY: 0,
    ballHeight: 0,
    p1Points: 0,
    p2Points: 0,
    p1Games: 0,
    p2Games: 0,
    phase: PHASE.WAITING,
    countdown: 3,
    server: 1,
    isTiebreak: false,
    hitEvent: false,
    serveEvent: false,
    netFault: false,
    outOfBounds: false,
    faultEvent: false,
    isSecondServe: false,
    outType: OUT_TYPE.NONE,
    pointWinner: 0,
    announcement: ANNOUNCEMENT.NONE,
    lastHitter: 0,
    rallyCount: 0,
    gameMode: GAME_MODE.CLASSIC,
    serveTimer: 150,
    ...overrides,
  };
}

describe("tennis_protocol", () => {
  describe("GAME_STATE encode/decode", () => {
    it("roundtrips a full game state", () => {
      const state = makeState({
        p1x: 280,
        p1y: 400,
        p2x: 350,
        p2y: 80,
        ballX: 310.5,
        ballY: 200.3,
        ballVX: 4.5,
        ballVY: -3.25,
        ballHeight: 0.5,
        p1Points: 3,
        p2Points: 2,
        p1Games: 4,
        p2Games: 5,
        phase: PHASE.RALLY,
        countdown: 0,
        server: 2,
        isTiebreak: false,
        hitEvent: true,
        serveEvent: false,
        netFault: false,
        outOfBounds: false,
        faultEvent: false,
        isSecondServe: true,
        outType: OUT_TYPE.NONE,
        pointWinner: 0,
        announcement: ANNOUNCEMENT.DEUCE,
        lastHitter: 1,
        rallyCount: 7,
        gameMode: GAME_MODE.CLASSIC,
        serveTimer: 100,
      });

      const buf = encodeGameState(state);
      const decoded = decodeGameState(buf);

      expect(decoded.p1x).toBe(280);
      expect(decoded.p1y).toBe(400);
      expect(decoded.p2x).toBe(350);
      expect(decoded.p2y).toBe(80);
      expect(decoded.ballX).toBeCloseTo(310.5, 0);
      expect(decoded.ballY).toBeCloseTo(200.3, 0);
      expect(decoded.ballVX).toBeCloseTo(4.5, 1);
      expect(decoded.ballVY).toBeCloseTo(-3.25, 1);
      expect(decoded.ballHeight).toBeCloseTo(0.5, 1);
      expect(decoded.p1Points).toBe(3);
      expect(decoded.p2Points).toBe(2);
      expect(decoded.p1Games).toBe(4);
      expect(decoded.p2Games).toBe(5);
      expect(decoded.phase).toBe(PHASE.RALLY);
      expect(decoded.countdown).toBe(0);
      expect(decoded.server).toBe(2);
      expect(decoded.isTiebreak).toBe(false);
      expect(decoded.hitEvent).toBe(true);
      expect(decoded.serveEvent).toBe(false);
      expect(decoded.netFault).toBe(false);
      expect(decoded.outOfBounds).toBe(false);
      expect(decoded.faultEvent).toBe(false);
      expect(decoded.isSecondServe).toBe(true);
      expect(decoded.outType).toBe(OUT_TYPE.NONE);
      expect(decoded.pointWinner).toBe(0);
      expect(decoded.announcement).toBe(ANNOUNCEMENT.DEUCE);
      expect(decoded.lastHitter).toBe(1);
      expect(decoded.rallyCount).toBe(7);
      expect(decoded.gameMode).toBe(GAME_MODE.CLASSIC);
      expect(decoded.serveTimer).toBeCloseTo(100, -1);
    });

    it("produces exactly 32 bytes", () => {
      const buf = encodeGameState(makeState());
      expect(buf.byteLength).toBe(32);
    });

    it("sets type byte to GAME_STATE (0x80)", () => {
      const buf = encodeGameState(makeState());
      expect(new DataView(buf).getUint8(0)).toBe(0x80);
    });

    it("handles max position values (640, 480)", () => {
      const state = makeState({ p1x: 640, p1y: 480, p2x: 640, p2y: 480 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.p1x).toBe(640);
      expect(decoded.p1y).toBe(480);
      expect(decoded.p2x).toBe(640);
      expect(decoded.p2y).toBe(480);
    });

    it("handles negative ball velocities (Int16)", () => {
      const state = makeState({ ballVX: -5.5, ballVY: -3.25 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ballVX).toBeCloseTo(-5.5, 1);
      expect(decoded.ballVY).toBeCloseTo(-3.25, 1);
    });

    it("encodes ball height as 0-255 range", () => {
      const s0 = makeState({ ballHeight: 0 });
      expect(decodeGameState(encodeGameState(s0)).ballHeight).toBeCloseTo(0, 1);

      const s1 = makeState({ ballHeight: 1.0 });
      expect(decodeGameState(encodeGameState(s1)).ballHeight).toBeCloseTo(1.0, 1);

      const sMid = makeState({ ballHeight: 0.5 });
      expect(decodeGameState(encodeGameState(sMid)).ballHeight).toBeCloseTo(0.5, 1);
    });

    it("handles all phase values", () => {
      for (const [, value] of Object.entries(PHASE)) {
        const state = makeState({ phase: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.phase).toBe(value);
      }
    });

    it("packs/unpacks all flag bits correctly", () => {
      // Test each flag individually
      const flags = [
        ["server", 2, "server"],
        ["isTiebreak", true, "isTiebreak"],
        ["hitEvent", true, "hitEvent"],
        ["serveEvent", true, "serveEvent"],
        ["netFault", true, "netFault"],
        ["outOfBounds", true, "outOfBounds"],
        ["faultEvent", true, "faultEvent"],
        ["isSecondServe", true, "isSecondServe"],
      ];

      for (const [key, value, decodedKey] of flags) {
        const state = makeState({ [key]: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded[decodedKey]).toBe(value);
      }
    });

    it("handles all announcement values", () => {
      for (const [, value] of Object.entries(ANNOUNCEMENT)) {
        const state = makeState({ announcement: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.announcement).toBe(value);
      }
    });

    it("handles all outType values", () => {
      for (const [, value] of Object.entries(OUT_TYPE)) {
        const state = makeState({ outType: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.outType).toBe(value);
      }
    });

    it("handles all game modes", () => {
      for (const [, value] of Object.entries(GAME_MODE)) {
        const state = makeState({ gameMode: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.gameMode).toBe(value);
      }
    });

    it("handles countdown values 0-3", () => {
      for (let cd = 0; cd <= 3; cd++) {
        const state = makeState({ countdown: cd, phase: PHASE.COUNTDOWN });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.countdown).toBe(cd);
      }
    });

    it("returns null for buffer too small", () => {
      expect(decodeGameState(new ArrayBuffer(31))).toBeNull();
      expect(decodeGameState(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(32);
      new DataView(buf).setUint8(0, 0x81);
      expect(decodeGameState(buf)).toBeNull();
    });
  });

  describe("PLAYER_INPUT encode/decode", () => {
    it("roundtrips each INPUT_KEY", () => {
      for (const [, key] of Object.entries(INPUT_KEY)) {
        const buf = encodePlayerInput(key, true);
        const decoded = decodePlayerInput(buf);
        expect(decoded.keyCode).toBe(key);
        expect(decoded.pressed).toBe(true);
      }
    });

    it("roundtrips pressed=true and pressed=false", () => {
      const bufT = encodePlayerInput(INPUT_KEY.UP, true);
      expect(decodePlayerInput(bufT).pressed).toBe(true);

      const bufF = encodePlayerInput(INPUT_KEY.UP, false);
      expect(decodePlayerInput(bufF).pressed).toBe(false);
    });

    it("produces exactly 3 bytes", () => {
      const buf = encodePlayerInput(INPUT_KEY.SERVE, true);
      expect(buf.byteLength).toBe(3);
    });

    it("sets type byte to PLAYER_INPUT (0x81)", () => {
      const buf = encodePlayerInput(INPUT_KEY.UP, true);
      expect(new DataView(buf).getUint8(0)).toBe(0x81);
    });

    it("returns null for buffer too small", () => {
      expect(decodePlayerInput(new ArrayBuffer(2))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      new DataView(buf).setUint8(0, 0x80);
      expect(decodePlayerInput(buf)).toBeNull();
    });
  });

  describe("GAME_END encode/decode", () => {
    it("roundtrips P1 wins Classic 6-4", () => {
      const buf = encodeGameEnd(6, 4, 1, GAME_MODE.CLASSIC, false);
      expect(buf.byteLength).toBe(6);
      const decoded = decodeGameEnd(buf);
      expect(decoded.p1Games).toBe(6);
      expect(decoded.p2Games).toBe(4);
      expect(decoded.winner).toBe(1);
      expect(decoded.gameMode).toBe(GAME_MODE.CLASSIC);
      expect(decoded.wasTiebreak).toBe(false);
    });

    it("roundtrips P2 wins Quick 3-1", () => {
      const decoded = decodeGameEnd(encodeGameEnd(1, 3, 2, GAME_MODE.QUICK, false));
      expect(decoded.p1Games).toBe(1);
      expect(decoded.p2Games).toBe(3);
      expect(decoded.winner).toBe(2);
      expect(decoded.gameMode).toBe(GAME_MODE.QUICK);
    });

    it("roundtrips tiebreak flag", () => {
      const decoded = decodeGameEnd(encodeGameEnd(6, 7, 2, GAME_MODE.CLASSIC, true));
      expect(decoded.wasTiebreak).toBe(true);
      expect(decoded.p1Games).toBe(6);
      expect(decoded.p2Games).toBe(7);
    });

    it("sets type byte to GAME_END (0x83)", () => {
      const buf = encodeGameEnd(0, 0, 1, GAME_MODE.CLASSIC, false);
      expect(new DataView(buf).getUint8(0)).toBe(0x83);
    });

    it("returns null for buffer too small", () => {
      expect(decodeGameEnd(new ArrayBuffer(5))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(6);
      new DataView(buf).setUint8(0, 0x80);
      expect(decodeGameEnd(buf)).toBeNull();
    });
  });

  describe("GAME_READY encode", () => {
    it("produces 1 byte with type GAME_READY", () => {
      const buf = encodeGameReady();
      expect(buf.byteLength).toBe(1);
      expect(new DataView(buf).getUint8(0)).toBe(0x84);
    });
  });

  describe("getMessageType", () => {
    it("returns type byte from any buffer", () => {
      expect(getMessageType(encodeGameReady())).toBe(MSG_TYPE.GAME_READY);
      expect(getMessageType(encodePlayerInput(0, true))).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(getMessageType(encodeGameState(makeState()))).toBe(MSG_TYPE.GAME_STATE);
      expect(getMessageType(encodeGameEnd(0, 0, 1, GAME_MODE.CLASSIC, false))).toBe(
        MSG_TYPE.GAME_END,
      );
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });
  });

  describe("protocol boundary values", () => {
    it("clamps negative ballX to 0", () => {
      const state = makeState({ ballX: -5.0 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ballX).toBe(0);
    });

    it("clamps negative ballY to 0", () => {
      const state = makeState({ ballY: -10.0 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ballY).toBe(0);
    });

    it("rallyCount clamps at 255", () => {
      const state = makeState({ rallyCount: 300 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.rallyCount).toBe(255);
    });

    it("ballHeight clamps at 0-1 range", () => {
      const stateLow = makeState({ ballHeight: -0.5 });
      const decodedLow = decodeGameState(encodeGameState(stateLow));
      expect(decodedLow.ballHeight).toBeGreaterThanOrEqual(0);

      const stateHigh = makeState({ ballHeight: 2.0 });
      const decodedHigh = decodeGameState(encodeGameState(stateHigh));
      expect(decodedHigh.ballHeight).toBeLessThanOrEqual(1.0);
    });

    it("serveTimer encodes with >>2 precision", () => {
      const state = makeState({ serveTimer: 600 });
      const decoded = decodeGameState(encodeGameState(state));
      // 600 >> 2 = 150, decoded << 2 = 600
      expect(decoded.serveTimer).toBe(600);
    });

    it("all flags false produces flags byte = 0", () => {
      const state = makeState({
        server: 1,
        isTiebreak: false,
        hitEvent: false,
        serveEvent: false,
        netFault: false,
        outOfBounds: false,
        faultEvent: false,
        isSecondServe: false,
      });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.server).toBe(1);
      expect(decoded.isTiebreak).toBe(false);
      expect(decoded.hitEvent).toBe(false);
    });

    it("all flags true produces correct decode", () => {
      const state = makeState({
        server: 2,
        isTiebreak: true,
        hitEvent: true,
        serveEvent: true,
        netFault: true,
        outOfBounds: true,
        faultEvent: true,
        isSecondServe: true,
      });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.server).toBe(2);
      expect(decoded.isTiebreak).toBe(true);
      expect(decoded.hitEvent).toBe(true);
      expect(decoded.serveEvent).toBe(true);
      expect(decoded.netFault).toBe(true);
      expect(decoded.outOfBounds).toBe(true);
      expect(decoded.faultEvent).toBe(true);
      expect(decoded.isSecondServe).toBe(true);
    });
  });

  describe("protocol constants", () => {
    it("all message types are >= 0x80 (game message range)", () => {
      for (const type of Object.values(MSG_TYPE)) {
        expect(type).toBeGreaterThanOrEqual(0x80);
      }
    });

    it("PHASE enum has 7 values (0-6)", () => {
      expect(Object.keys(PHASE)).toHaveLength(7);
      expect(PHASE.WAITING).toBe(0);
      expect(PHASE.GAME_OVER).toBe(6);
    });

    it("INPUT_KEY enum has 5 values", () => {
      expect(Object.keys(INPUT_KEY)).toHaveLength(5);
      expect(INPUT_KEY.UP).toBe(0);
      expect(INPUT_KEY.DOWN).toBe(1);
      expect(INPUT_KEY.LEFT).toBe(2);
      expect(INPUT_KEY.RIGHT).toBe(3);
      expect(INPUT_KEY.SERVE).toBe(4);
    });

    it("GAME_MODE enum has 3 values", () => {
      expect(Object.keys(GAME_MODE)).toHaveLength(3);
      expect(GAME_MODE.CLASSIC).toBe(0);
      expect(GAME_MODE.QUICK).toBe(1);
      expect(GAME_MODE.SUDDEN_DEATH).toBe(2);
    });

    it("ANNOUNCEMENT enum has 6 values", () => {
      expect(Object.keys(ANNOUNCEMENT)).toHaveLength(6);
      expect(ANNOUNCEMENT.NONE).toBe(0);
      expect(ANNOUNCEMENT.TIEBREAK).toBe(5);
    });

    it("OUT_TYPE enum has 5 values", () => {
      expect(Object.keys(OUT_TYPE)).toHaveLength(5);
      expect(OUT_TYPE.NONE).toBe(0);
      expect(OUT_TYPE.DEAD).toBe(4);
    });
  });
});
