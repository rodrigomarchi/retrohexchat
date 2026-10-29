import { describe, expect, it } from "vitest";
import { SCREENS, SEED, TREASURE } from "../../../../js/lib/games/hex_jungle/protocol.js";
import {
  decodeScene,
  stepLeft,
  stepRight,
  stepScreens,
  treasureSlot,
} from "../../../../js/lib/games/hex_jungle/world.js";

const BYTES = [...Array(255).keys()].map((i) => i + 1);

/** The 255 screens in the order walking right meets them, from the start. */
function ring() {
  const screens = [SEED];
  while (screens.length < SCREENS) screens.push(stepRight(screens.at(-1)));
  return screens;
}

const sceneOf = (byte) => (byte >> 3) & 7;

describe("the world's generator", () => {
  it("steps left and right as each other's inverse, for every screen", () => {
    for (const r of BYTES) {
      expect(stepLeft(stepRight(r))).toBe(r);
      expect(stepRight(stepLeft(r))).toBe(r);
    }
  });

  it("walks a ring of 255 screens from the start, never repeating and never reaching 0", () => {
    const screens = ring();
    expect(new Set(screens).size).toBe(SCREENS);
    expect(screens).not.toContain(0);
    expect(stepRight(screens.at(-1))).toBe(SEED);
  });

  it("steps three screens at a time underground", () => {
    for (const r of [SEED, 1, 77, 255]) {
      expect(stepScreens(r, 3, 1)).toBe(stepRight(stepRight(stepRight(r))));
      expect(stepScreens(r, 3, -1)).toBe(stepLeft(stepLeft(stepLeft(r))));
    }
  });

  it("deals the scenes out evenly: 32 of each, one fewer of the first, and 8 of each treasure", () => {
    const counts = Array(8).fill(0);
    for (const byte of ring()) counts[sceneOf(byte)]++;
    expect(counts).toEqual([31, 32, 32, 32, 32, 32, 32, 32]);

    const treasures = ring()
      .map((byte) => decodeScene(byte).treasure)
      .filter(Boolean);
    expect(treasures).toHaveLength(32);
    for (const kind of Object.values(TREASURE)) {
      expect(treasures.filter((t) => t.kind === kind.kind)).toHaveLength(8);
    }
  });
});

describe("a screen's byte", () => {
  // Scene in bits 3-5, the object in bits 0-2, the trees in bits 6-7.
  const byte = (scene, object = 0, top = 0) => (top << 6) | (scene << 3) | object;

  it("scene 0: one hole with a ladder, a wall below on the side bit 7 names", () => {
    const left = decodeScene(byte(0, 1, 0));
    expect(left.ladder).toBe(true);
    expect(left.holes).toEqual([[72, 79]]);
    expect(left.pit).toBeNull();
    expect(left.vine).toBe(false);
    expect(left.underground).toEqual({ wall: "left", scorpion: false });
    expect(decodeScene(byte(0, 1, 2)).underground).toEqual({ wall: "right", scorpion: false });
  });

  it("scene 1: the ladder's hole and one each side", () => {
    expect(decodeScene(byte(1)).holes).toEqual([
      [44, 55],
      [72, 79],
      [96, 107],
    ]);
  });

  it("scenes 2 to 7: a pit, a vine where the original had one, and a scorpion below", () => {
    const pits = [2, 3, 4, 5, 6, 7].map((scene) => decodeScene(byte(scene)));
    expect(pits.map((s) => s.pit)).toEqual([
      { kind: "tar", shifting: false, crocodiles: false },
      { kind: "swamp", shifting: false, crocodiles: false },
      { kind: "swamp", shifting: false, crocodiles: true },
      { kind: "tar", shifting: true, crocodiles: false },
      { kind: "tar", shifting: true, crocodiles: false },
      { kind: "quicksand", shifting: true, crocodiles: false },
    ]);
    expect(pits.map((s) => s.vine)).toEqual([true, true, false, false, true, false]);
    for (const scene of pits) {
      expect(scene.ladder).toBe(false);
      expect(scene.holes).toEqual([]);
      expect(scene.underground).toEqual({ wall: null, scorpion: true });
    }
  });

  it("crocodiles have a vine only when the object's second bit is set", () => {
    expect(decodeScene(byte(4, 0b010)).vine).toBe(true);
    expect(decodeScene(byte(4, 0b101)).vine).toBe(false);
  });

  it("the object: logs, fire or a snake — none beside crocodiles or a treasure", () => {
    // ex_dna:disable-for-lines:10 the expected table written out, apart from the code
    expect([0, 1, 2, 3, 4, 5, 6, 7].map((o) => decodeScene(byte(2, o)).hazard)).toEqual([
      { kind: "log", count: 1, rolling: true, spread: "close" },
      { kind: "log", count: 2, rolling: true, spread: "close" },
      { kind: "log", count: 2, rolling: true, spread: "wide" },
      { kind: "log", count: 3, rolling: true, spread: "close" },
      { kind: "log", count: 1, rolling: false, spread: "close" },
      { kind: "log", count: 3, rolling: false, spread: "close" },
      { kind: "fire" },
      { kind: "snake" },
    ]);
    expect(decodeScene(byte(4, 6)).hazard).toBeNull();
    expect(decodeScene(byte(5, 6)).hazard).toBeNull();
  });

  it("a treasure scene names its treasure by the object's two low bits", () => {
    expect([0, 1, 2, 3].map((o) => decodeScene(byte(5, o)).treasure)).toEqual([
      TREASURE.MONEY,
      TREASURE.SILVER,
      TREASURE.GOLD,
      TREASURE.RING,
    ]);
    expect(TREASURE.MONEY.points).toBe(2000);
    expect(TREASURE.RING.points).toBe(5000);
    expect(decodeScene(byte(2, 1)).treasure).toBeNull();
  });

  it("keeps the trees' pattern", () => {
    expect([0, 1, 2, 3].map((top) => decodeScene(byte(2, 0, top)).trees)).toEqual([0, 1, 2, 3]);
  });
});

describe("treasureSlot", () => {
  it("gives each of the 32 treasures a place of its own in the record of those taken", () => {
    const slots = ring()
      .filter((b) => decodeScene(b).treasure)
      .map(treasureSlot);
    expect(new Set(slots).size).toBe(32);
    for (const slot of slots) {
      expect(slot).toBeGreaterThanOrEqual(0);
      expect(slot).toBeLessThan(32);
    }
  });
});
