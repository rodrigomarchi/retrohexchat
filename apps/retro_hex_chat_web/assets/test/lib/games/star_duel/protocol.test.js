import { describe, it, expect } from "vitest";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  encodeShipFlags,
  decodeShipFlags,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "../../../../js/lib/games/star_duel/protocol.js";

const MISSILE_SIZE = 18;
const GAME_STATE_HEADER_SIZE = 51;

function makeShip(overrides = {}) {
  return {
    x: 100.5,
    y: 200.25,
    vx: 3.5,
    vy: -2.75,
    rotation: 1.5708,
    flags: encodeShipFlags({
      alive: true,
      thrustActive: false,
      exploding: false,
      warping: false,
      invulnerable: false,
    }),
    ...overrides,
  };
}

function makeState(overrides = {}) {
  return {
    ship1: makeShip(),
    ship2: makeShip({ x: 500, y: 300, vx: -1.0, vy: 2.0, rotation: 3.1416 }),
    score1: 3,
    score2: 5,
    phase: PHASE.PLAYING,
    countdown: 0,
    mode: GAME_MODE.OPEN_SPACE,
    missiles: [],
    invuln1: 0,
    invuln2: 0,
    warpCooldown1: 0,
    warpCooldown2: 0,
    asteroidSeed: 42,
    ...overrides,
  };
}

describe("star_duel_protocol", () => {
  describe("GAME_STATE encode/decode", () => {
    it("roundtrips with 0 missiles (51 bytes)", () => {
      const state = makeState();
      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(GAME_STATE_HEADER_SIZE);

      const decoded = decodeGameState(buf);
      expect(decoded.ship1.x).toBeCloseTo(100.5, 1);
      expect(decoded.ship1.y).toBeCloseTo(200.25, 1);
      expect(decoded.ship1.vx).toBeCloseTo(3.5, 1);
      expect(decoded.ship1.vy).toBeCloseTo(-2.75, 1);
      expect(decoded.ship1.flags.alive).toBe(true);
      expect(decoded.ship1.flags.thrustActive).toBe(false);
      expect(decoded.ship2.x).toBeCloseTo(500, 1);
      expect(decoded.ship2.y).toBeCloseTo(300, 1);
      expect(decoded.score1).toBe(3);
      expect(decoded.score2).toBe(5);
      expect(decoded.phase).toBe(PHASE.PLAYING);
      expect(decoded.countdown).toBe(0);
      expect(decoded.mode).toBe(GAME_MODE.OPEN_SPACE);
      expect(decoded.missiles).toHaveLength(0);
      expect(decoded.invuln1).toBe(0);
      expect(decoded.invuln2).toBe(0);
      expect(decoded.warpCooldown1).toBe(0);
      expect(decoded.warpCooldown2).toBe(0);
      expect(decoded.asteroidSeed).toBe(42);
    });

    it("roundtrips with max 6 missiles", () => {
      const missiles = [];
      for (let i = 0; i < 6; i++) {
        missiles.push({
          x: 10.5 + i * 50,
          y: 20.25 + i * 30,
          vx: 3.0 + i,
          vy: -1.5 + i,
          owner: i % 2,
          age: i * 5,
        });
      }
      const state = makeState({ missiles });
      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(GAME_STATE_HEADER_SIZE + 6 * MISSILE_SIZE);

      const decoded = decodeGameState(buf);
      expect(decoded.missiles).toHaveLength(6);
      for (let i = 0; i < 6; i++) {
        expect(decoded.missiles[i].x).toBeCloseTo(10.5 + i * 50, 1);
        expect(decoded.missiles[i].y).toBeCloseTo(20.25 + i * 30, 1);
        expect(decoded.missiles[i].vx).toBeCloseTo(3.0 + i, 1);
        expect(decoded.missiles[i].vy).toBeCloseTo(-1.5 + i, 1);
        expect(decoded.missiles[i].owner).toBe(i % 2);
        expect(decoded.missiles[i].age).toBe(i * 5);
      }
    });

    it("roundtrips with 3 missiles", () => {
      const missiles = [
        { x: 100.0, y: 200.0, vx: 5.0, vy: -3.0, owner: 0, age: 10 },
        { x: 300.5, y: 400.5, vx: -2.0, vy: 1.5, owner: 1, age: 20 },
        { x: 50.25, y: 75.75, vx: 0, vy: 0, owner: 0, age: 3 },
      ];
      const state = makeState({ missiles });
      const buf = encodeGameState(state);
      expect(buf.byteLength).toBe(GAME_STATE_HEADER_SIZE + 3 * MISSILE_SIZE);

      const decoded = decodeGameState(buf);
      expect(decoded.missiles).toHaveLength(3);
      expect(decoded.missiles[0].x).toBeCloseTo(100.0, 1);
      expect(decoded.missiles[1].owner).toBe(1);
      expect(decoded.missiles[2].age).toBe(3);
    });

    it("preserves ship rotation precision (encode pi, decode close to pi)", () => {
      const ship = makeShip({ rotation: Math.PI });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      // Uint16 scaled by 10000: precision ~0.0001 radians
      expect(decoded.ship1.rotation).toBeCloseTo(Math.PI, 3);
    });

    it("handles all phase values", () => {
      for (const [, value] of Object.entries(PHASE)) {
        const state = makeState({ phase: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.phase).toBe(value);
      }
    });

    it("handles all mode values", () => {
      for (const [, value] of Object.entries(GAME_MODE)) {
        const state = makeState({ mode: value });
        const decoded = decodeGameState(encodeGameState(state));
        expect(decoded.mode).toBe(value);
      }
    });

    it("handles negative velocities", () => {
      const ship = makeShip({ vx: -7.5, vy: -12.25 });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.vx).toBeCloseTo(-7.5, 1);
      expect(decoded.ship1.vy).toBeCloseTo(-12.25, 1);
    });

    it("returns null for buffer too small (< 51)", () => {
      expect(decodeGameState(new ArrayBuffer(50))).toBeNull();
      expect(decodeGameState(new ArrayBuffer(0))).toBeNull();
      expect(decodeGameState(new ArrayBuffer(1))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(51);
      new DataView(buf).setUint8(0, 0x81);
      expect(decodeGameState(buf)).toBeNull();
    });

    it("roundtrips invulnerability timers and warp cooldowns", () => {
      const state = makeState({
        invuln1: 120,
        invuln2: 60,
        warpCooldown1: 200,
        warpCooldown2: 150,
      });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.invuln1).toBe(120);
      expect(decoded.invuln2).toBe(60);
      expect(decoded.warpCooldown1).toBe(200);
      expect(decoded.warpCooldown2).toBe(150);
    });

    it("roundtrips asteroidSeed", () => {
      const state = makeState({ asteroidSeed: 65535 });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.asteroidSeed).toBe(65535);
    });

    it("sets type byte to GAME_STATE (0x80)", () => {
      const buf = encodeGameState(makeState());
      expect(new DataView(buf).getUint8(0)).toBe(0x80);
    });

    it("missile vx/vy roundtrip encode/decode", () => {
      const missiles = [
        { x: 50, y: 100, vx: 7.25, vy: -4.5, owner: 0, age: 5 },
        { x: 200, y: 300, vx: -3.125, vy: 6.75, owner: 1, age: 12 },
      ];
      const state = makeState({ missiles });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.missiles[0].vx).toBeCloseTo(7.25, 1);
      expect(decoded.missiles[0].vy).toBeCloseTo(-4.5, 1);
      expect(decoded.missiles[1].vx).toBeCloseTo(-3.125, 1);
      expect(decoded.missiles[1].vy).toBeCloseTo(6.75, 1);
    });

    it("missiles > MAX_MISSILES (6) are clamped", () => {
      const missiles = [];
      for (let i = 0; i < 10; i++) {
        missiles.push({ x: i * 10, y: i * 10, vx: 0, vy: 0, owner: 0, age: 0 });
      }
      const state = makeState({ missiles });
      const buf = encodeGameState(state);
      // Should only encode 6 missiles
      expect(buf.byteLength).toBe(GAME_STATE_HEADER_SIZE + 6 * MISSILE_SIZE);
      const decoded = decodeGameState(buf);
      expect(decoded.missiles).toHaveLength(6);
    });

    it("missile count vs buffer mismatch — truncated buffer stops reading", () => {
      // Create a valid 2-missile buffer, then truncate it
      const missiles = [
        { x: 10, y: 20, vx: 1, vy: 2, owner: 0, age: 1 },
        { x: 30, y: 40, vx: 3, vy: 4, owner: 1, age: 2 },
      ];
      const state = makeState({ missiles });
      const fullBuf = encodeGameState(state);
      const fullSize = fullBuf.byteLength;

      // Truncate so only 1 missile fits: header + 1 missile but missileCount says 2
      const truncatedSize = GAME_STATE_HEADER_SIZE + MISSILE_SIZE;
      const truncated = fullBuf.slice(0, truncatedSize);
      // Missile count in header still says 2, but only 1 missile fits
      const decoded = decodeGameState(truncated);
      expect(decoded).not.toBeNull();
      // Should only have 1 missile since the second doesn't fit
      expect(decoded.missiles.length).toBeLessThan(2);
      expect(decoded.missileCount).toBe(decoded.missiles.length);

      // Verify the full buffer decodes both
      const fullDecoded = decodeGameState(fullBuf);
      expect(fullDecoded.missiles).toHaveLength(2);
      expect(fullSize).toBe(GAME_STATE_HEADER_SIZE + 2 * MISSILE_SIZE);
    });

    it("phase value > max is clamped to FINISHED (5)", () => {
      const state = makeState({ phase: PHASE.PLAYING });
      const buf = encodeGameState(state);
      const view = new DataView(buf);
      // Manually write an out-of-range phase value (e.g. 10)
      const metaOffset = 39;
      view.setUint8(metaOffset + 2, 10);
      const decoded = decodeGameState(buf);
      expect(decoded.phase).toBe(5); // clamped to PHASE.FINISHED
    });

    it("mode value > max is clamped to DEBRIS_FIELD (2)", () => {
      const state = makeState({ mode: GAME_MODE.OPEN_SPACE });
      const buf = encodeGameState(state);
      const view = new DataView(buf);
      const metaOffset = 39;
      view.setUint8(metaOffset + 4, 255);
      const decoded = decodeGameState(buf);
      expect(decoded.mode).toBe(2); // clamped to GAME_MODE.DEBRIS_FIELD
    });

    it("decodeGameState missileCount uses missiles.length", () => {
      // When buffer has missileCount=3 but only 2 missiles fit,
      // decoded.missileCount should equal missiles.length (2), not the raw header value (3)
      const missiles = [
        { x: 10, y: 20, vx: 1, vy: 2, owner: 0, age: 1 },
        { x: 30, y: 40, vx: 3, vy: 4, owner: 1, age: 2 },
        { x: 50, y: 60, vx: 5, vy: 6, owner: 0, age: 3 },
      ];
      const state = makeState({ missiles });
      const fullBuf = encodeGameState(state);
      // Truncate to only fit 2 missiles (header says 3)
      const truncated = fullBuf.slice(0, GAME_STATE_HEADER_SIZE + 2 * MISSILE_SIZE);
      const decoded = decodeGameState(truncated);
      expect(decoded.missileCount).toBe(2);
      expect(decoded.missiles).toHaveLength(2);
    });
  });

  describe("writeShip auto-encode flags", () => {
    it("accepts flags as a pre-encoded number", () => {
      const flagsNum = encodeShipFlags({
        alive: true,
        thrustActive: true,
        exploding: false,
        warping: false,
        invulnerable: false,
      });
      const ship = makeShip({ flags: flagsNum });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.flags.alive).toBe(true);
      expect(decoded.ship1.flags.thrustActive).toBe(true);
      expect(decoded.ship1.flags.exploding).toBe(false);
    });

    it("accepts flags as an object (auto-encoded)", () => {
      const ship = makeShip({
        flags: {
          alive: true,
          thrustActive: false,
          exploding: true,
          warping: false,
          invulnerable: true,
        },
      });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.flags.alive).toBe(true);
      expect(decoded.ship1.flags.thrustActive).toBe(false);
      expect(decoded.ship1.flags.exploding).toBe(true);
      expect(decoded.ship1.flags.warping).toBe(false);
      expect(decoded.ship1.flags.invulnerable).toBe(true);
    });

    it("object flags produce same result as numeric flags", () => {
      const flagsObj = {
        alive: true,
        thrustActive: false,
        exploding: true,
        warping: true,
        invulnerable: false,
      };
      const flagsNum = encodeShipFlags(flagsObj);

      const shipWithObj = makeShip({ flags: flagsObj });
      const shipWithNum = makeShip({ flags: flagsNum });

      const decodedObj = decodeGameState(encodeGameState(makeState({ ship1: shipWithObj })));
      const decodedNum = decodeGameState(encodeGameState(makeState({ ship1: shipWithNum })));

      expect(decodedObj.ship1.flags).toEqual(decodedNum.ship1.flags);
    });
  });

  describe("rotation clamping", () => {
    it("normalizes rotation > 2*PI", () => {
      const ship = makeShip({ rotation: Math.PI * 2 + 1.0 });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.rotation).toBeCloseTo(1.0, 3);
    });

    it("normalizes negative rotation", () => {
      const ship = makeShip({ rotation: -1.0 });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      // -1.0 normalized to 2*PI - 1.0
      expect(decoded.ship1.rotation).toBeCloseTo(Math.PI * 2 - 1.0, 3);
    });

    it("normalizes very large rotation (> 4*PI)", () => {
      const ship = makeShip({ rotation: Math.PI * 6 + 0.5 });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.rotation).toBeCloseTo(0.5, 3);
    });

    it("rotation of 0 stays 0", () => {
      const ship = makeShip({ rotation: 0 });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.rotation).toBeCloseTo(0, 3);
    });

    it("rotation of exactly 2*PI normalizes to 0", () => {
      const ship = makeShip({ rotation: Math.PI * 2 });
      const state = makeState({ ship1: ship });
      const decoded = decodeGameState(encodeGameState(state));
      expect(decoded.ship1.rotation).toBeCloseTo(0, 3);
    });
  });

  describe("encodeShipFlags / decodeShipFlags", () => {
    it("roundtrips all-false flags", () => {
      const flags = {
        alive: false,
        thrustActive: false,
        exploding: false,
        warping: false,
        invulnerable: false,
      };
      const byte = encodeShipFlags(flags);
      expect(byte).toBe(0);
      const decoded = decodeShipFlags(byte);
      expect(decoded).toEqual(flags);
    });

    it("roundtrips all-true flags", () => {
      const flags = {
        alive: true,
        thrustActive: true,
        exploding: true,
        warping: true,
        invulnerable: true,
      };
      const byte = encodeShipFlags(flags);
      expect(byte).toBe(0b11111);
      const decoded = decodeShipFlags(byte);
      expect(decoded).toEqual(flags);
    });

    it("roundtrips each individual flag", () => {
      const flagNames = ["alive", "thrustActive", "exploding", "warping", "invulnerable"];
      for (const name of flagNames) {
        const flags = {
          alive: false,
          thrustActive: false,
          exploding: false,
          warping: false,
          invulnerable: false,
        };
        flags[name] = true;
        const decoded = decodeShipFlags(encodeShipFlags(flags));
        expect(decoded[name]).toBe(true);
        // All others should be false
        for (const other of flagNames) {
          if (other !== name) {
            expect(decoded[other]).toBe(false);
          }
        }
      }
    });

    it("roundtrips all 32 combinations of 5 boolean flags", () => {
      for (let i = 0; i < 32; i++) {
        const flags = {
          alive: (i & 1) !== 0,
          thrustActive: (i & 2) !== 0,
          exploding: (i & 4) !== 0,
          warping: (i & 8) !== 0,
          invulnerable: (i & 16) !== 0,
        };
        const decoded = decodeShipFlags(encodeShipFlags(flags));
        expect(decoded).toEqual(flags);
      }
    });
  });

  describe("PLAYER_INPUT encode/decode", () => {
    it("roundtrips all 5 input keys (pressed)", () => {
      for (const [, value] of Object.entries(INPUT_KEY)) {
        const buf = encodePlayerInput(value, true);
        expect(buf.byteLength).toBe(3);
        const decoded = decodePlayerInput(buf);
        expect(decoded.keyCode).toBe(value);
        expect(decoded.pressed).toBe(true);
      }
    });

    it("roundtrips all 5 input keys (released)", () => {
      for (const [, value] of Object.entries(INPUT_KEY)) {
        const decoded = decodePlayerInput(encodePlayerInput(value, false));
        expect(decoded.keyCode).toBe(value);
        expect(decoded.pressed).toBe(false);
      }
    });

    it("sets type byte to PLAYER_INPUT (0x81)", () => {
      const buf = encodePlayerInput(INPUT_KEY.ROTATE_LEFT, true);
      expect(new DataView(buf).getUint8(0)).toBe(0x81);
    });

    it("returns null for buffer too small", () => {
      expect(decodePlayerInput(new ArrayBuffer(2))).toBeNull();
      expect(decodePlayerInput(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(3);
      new DataView(buf).setUint8(0, 0x80);
      expect(decodePlayerInput(buf)).toBeNull();
    });

    it("decodePlayerInput with pressed byte value 2 treats as true", () => {
      const buf = new ArrayBuffer(3);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      view.setUint8(1, INPUT_KEY.FIRE);
      view.setUint8(2, 2); // non-zero, non-1
      const decoded = decodePlayerInput(buf);
      expect(decoded.pressed).toBe(true);
    });

    it("decodePlayerInput with pressed byte value 255 treats as true", () => {
      const buf = new ArrayBuffer(3);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      view.setUint8(1, INPUT_KEY.THRUST);
      view.setUint8(2, 255);
      const decoded = decodePlayerInput(buf);
      expect(decoded.pressed).toBe(true);
    });

    it("decodePlayerInput with pressed byte value 0 treats as false", () => {
      const buf = new ArrayBuffer(3);
      const view = new DataView(buf);
      view.setUint8(0, MSG_TYPE.PLAYER_INPUT);
      view.setUint8(1, INPUT_KEY.WARP);
      view.setUint8(2, 0);
      const decoded = decodePlayerInput(buf);
      expect(decoded.pressed).toBe(false);
    });
  });

  describe("GAME_END encode/decode", () => {
    it("roundtrips player 1 win", () => {
      const buf = encodeGameEnd(5, 3, 1);
      expect(buf.byteLength).toBe(4);
      const decoded = decodeGameEnd(buf);
      expect(decoded.score1).toBe(5);
      expect(decoded.score2).toBe(3);
      expect(decoded.winner).toBe(1);
    });

    it("roundtrips player 2 win", () => {
      const decoded = decodeGameEnd(encodeGameEnd(2, 5, 2));
      expect(decoded.score1).toBe(2);
      expect(decoded.score2).toBe(5);
      expect(decoded.winner).toBe(2);
    });

    it("sets type byte to GAME_END (0x83)", () => {
      const buf = encodeGameEnd(0, 0, 1);
      expect(new DataView(buf).getUint8(0)).toBe(0x83);
    });

    it("returns null for buffer too small", () => {
      expect(decodeGameEnd(new ArrayBuffer(3))).toBeNull();
      expect(decodeGameEnd(new ArrayBuffer(0))).toBeNull();
    });

    it("returns null for wrong message type", () => {
      const buf = new ArrayBuffer(4);
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
    it("returns correct type for all message types", () => {
      expect(getMessageType(encodeGameReady())).toBe(MSG_TYPE.GAME_READY);
      expect(getMessageType(encodePlayerInput(INPUT_KEY.FIRE, true))).toBe(MSG_TYPE.PLAYER_INPUT);
      expect(getMessageType(encodeGameState(makeState()))).toBe(MSG_TYPE.GAME_STATE);
      expect(getMessageType(encodeGameEnd(0, 0, 1))).toBe(MSG_TYPE.GAME_END);
    });

    it("returns null for empty buffer", () => {
      expect(getMessageType(new ArrayBuffer(0))).toBeNull();
    });

    it("reads type from single byte buffer", () => {
      const buf = new ArrayBuffer(1);
      new DataView(buf).setUint8(0, 0x99);
      expect(getMessageType(buf)).toBe(0x99);
    });

    it("reads first byte only regardless of buffer size", () => {
      const buf = new ArrayBuffer(100);
      new DataView(buf).setUint8(0, 0x42);
      expect(getMessageType(buf)).toBe(0x42);
    });
  });

  describe("protocol constants", () => {
    it("all message types are >= 0x80 (game message range)", () => {
      for (const type of Object.values(MSG_TYPE)) {
        expect(type).toBeGreaterThanOrEqual(0x80);
      }
    });

    it("PHASE enum has 6 values (0-5)", () => {
      expect(Object.keys(PHASE)).toHaveLength(6);
      expect(PHASE.WAITING).toBe(0);
      expect(PHASE.FINISHED).toBe(5);
    });

    it("INPUT_KEY enum has 5 values (0-4)", () => {
      expect(Object.keys(INPUT_KEY)).toHaveLength(5);
      expect(INPUT_KEY.ROTATE_LEFT).toBe(0);
      expect(INPUT_KEY.WARP).toBe(4);
    });

    it("GAME_MODE enum has 3 values (0-2)", () => {
      expect(Object.keys(GAME_MODE)).toHaveLength(3);
      expect(GAME_MODE.OPEN_SPACE).toBe(0);
      expect(GAME_MODE.DEBRIS_FIELD).toBe(2);
    });
  });
});
