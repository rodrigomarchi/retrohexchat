import { describe, expect, it } from "vitest";
import {
  FAVORITES_KEY,
  keepFavorites,
  keepVolume,
  readFavorites,
  readVolume,
} from "../../../js/lib/radio/preferences.js";

function memoryStorage(initial = {}) {
  const items = new Map(Object.entries(initial));
  return () => ({
    getItem: (key) => (items.has(key) ? items.get(key) : null),
    setItem: (key, value) => items.set(key, String(value)),
  });
}

const broken = () => {
  throw new Error("storage is off");
};

describe("favorites", () => {
  it("come back in the order they were kept", () => {
    const storage = memoryStorage();
    keepFavorites(storage, ["b", "a"]);
    expect(readFavorites(storage)).toEqual(["b", "a"]);
  });

  it("ignore what is not a list of ids", () => {
    expect(readFavorites(memoryStorage({ [FAVORITES_KEY]: "{oops" }))).toEqual([]);
    expect(readFavorites(memoryStorage({ [FAVORITES_KEY]: '[1, "a", ""]' }))).toEqual(["a"]);
  });

  it("are empty, not an error, when storage is off", () => {
    expect(readFavorites(broken)).toEqual([]);
    expect(() => keepFavorites(broken, ["a"])).not.toThrow();
  });
});

describe("volume", () => {
  it("is kept between visits, within 0 to 100", () => {
    const storage = memoryStorage();
    expect(readVolume(storage)).toBe(80);
    keepVolume(storage, 35);
    expect(readVolume(storage)).toBe(35);
    expect(readVolume(memoryStorage({ "retrohex.radio.volume": "500" }))).toBe(100);
    expect(readVolume(broken)).toBe(80);
  });
});
