import { describe, it, expect } from "vitest";
import { alternate, hold, tap } from "./keys.js";

describe("key scripts", () => {
  it("holds a key between two times", () => {
    expect(hold("a", 10, 20)).toEqual([
      { at: 10, key: "a", down: true },
      { at: 20, key: "a", down: false },
    ]);
  });

  it("alternates keys and stops before the end", () => {
    expect(alternate(["u", "d"], { from: 0, until: 250, each: 100, gap: 10 })).toEqual([
      ...hold("u", 0, 100),
      ...hold("d", 110, 210),
    ]);
  });

  it("taps a key at a steady rhythm", () => {
    expect(tap("f", { from: 0, until: 300, every: 100, length: 50 })).toEqual([
      ...hold("f", 0, 50),
      ...hold("f", 100, 150),
      ...hold("f", 200, 250),
    ]);
  });
});
