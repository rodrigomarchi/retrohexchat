import { describe, expect, it } from "vitest";

import {
  hasOwn,
  idsFromValue,
  normalizeLayoutMode,
  normalizeSelfView,
  payloadValue,
  stringOrNull,
  tileDensity,
} from "../../../js/lib/group_call/payload.js";

describe("hasOwn", () => {
  it("is null-safe and checks own properties", () => {
    expect(hasOwn({ a: 1 }, "a")).toBe(true);
    expect(hasOwn({ a: 1 }, "b")).toBe(false);
    expect(hasOwn(null, "a")).toBe(false);
    expect(hasOwn(undefined, "toString")).toBe(false);
  });
});

describe("stringOrNull", () => {
  it("is null for empty, null and undefined", () => {
    expect(stringOrNull("")).toBeNull();
    expect(stringOrNull(null)).toBeNull();
    expect(stringOrNull(undefined)).toBeNull();
  });

  it("stringifies everything else", () => {
    expect(stringOrNull("x")).toBe("x");
    expect(stringOrNull(0)).toBe("0");
    expect(stringOrNull(42)).toBe("42");
  });
});

describe("idsFromValue", () => {
  it("splits a comma string and drops blanks", () => {
    expect(idsFromValue("a, b,,c")).toEqual(["a", "b", "c"]);
  });

  it("normalises an array", () => {
    expect(idsFromValue(["a", "", null, "b"])).toEqual(["a", "b"]);
  });

  it("is empty for anything else", () => {
    expect(idsFromValue(null)).toEqual([]);
    expect(idsFromValue(42)).toEqual([]);
  });
});

describe("payloadValue", () => {
  it("returns the first present key", () => {
    expect(payloadValue({ self_view: "pip" }, "self_view", "selfView")).toBe("pip");
    expect(payloadValue({ selfView: "tile" }, "self_view", "selfView")).toBe("tile");
  });

  it("returns undefined when no key is present", () => {
    expect(payloadValue({ x: 1 }, "a", "b")).toBeUndefined();
  });

  it("returns a present key even when its value is falsy", () => {
    expect(payloadValue({ a: 0 }, "a")).toBe(0);
    expect(payloadValue({ a: null }, "a")).toBeNull();
  });
});

describe("normalizeLayoutMode", () => {
  it("keeps valid modes and defaults the rest to auto", () => {
    for (const mode of ["auto", "grid", "focus", "sidebar", "speaker"]) {
      expect(normalizeLayoutMode(mode)).toBe(mode);
    }
    expect(normalizeLayoutMode("bogus")).toBe("auto");
    expect(normalizeLayoutMode(undefined)).toBe("auto");
  });
});

describe("normalizeSelfView", () => {
  it("keeps valid modes and defaults the rest to tile", () => {
    for (const mode of ["tile", "pip", "hidden"]) {
      expect(normalizeSelfView(mode)).toBe(mode);
    }
    expect(normalizeSelfView("bogus")).toBe("tile");
  });
});

describe("tileDensity", () => {
  it("buckets by count", () => {
    expect(tileDensity(0)).toBe("normal");
    expect(tileDensity(4)).toBe("normal");
    expect(tileDensity(5)).toBe("dense");
    expect(tileDensity(9)).toBe("dense");
    expect(tileDensity(10)).toBe("compact");
  });
});
