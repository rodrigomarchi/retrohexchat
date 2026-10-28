import { describe, expect, it } from "vitest";
import { KEYS, keyDown, keyUp } from "../../../../js/lib/games/hex_blocks/gestures.js";

describe("the keyboard", () => {
  it("holds the moves down while their keys are", () => {
    expect(keyDown({ key: "ArrowLeft" })).toEqual({ type: "press", input: "left" });
    expect(keyUp({ key: "ArrowLeft" })).toEqual({ type: "release", input: "left" });
    expect(keyDown({ key: "ArrowDown" })).toEqual({ type: "press", input: "down" });
    expect(keyUp({ key: "ArrowDown" })).toEqual({ type: "release", input: "down" });
  });

  it("turns, drops and holds on a press, and on nothing when the key comes up", () => {
    expect(keyDown({ key: "ArrowUp" })).toEqual({ type: "turn", dir: 1 });
    expect(keyDown({ key: "X" })).toEqual({ type: "turn", dir: 1 });
    expect(keyDown({ key: "z" })).toEqual({ type: "turn", dir: -1 });
    expect(keyDown({ key: " " })).toEqual({ type: "drop" });
    expect(keyDown({ key: "c" })).toEqual({ type: "hold" });
    expect(keyDown({ key: "Shift" })).toEqual({ type: "hold" });
    expect(keyUp({ key: " " })).toBeNull();
  });

  it("ignores the keyboard's own repeat, which the game makes itself", () => {
    expect(keyDown({ key: "ArrowLeft", repeat: true })).toBeNull();
    expect(keyDown({ key: "ArrowUp", repeat: true })).toBeNull();
  });

  it("takes every key it plays from the page, and only those", () => {
    for (const key of ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", " ", "z", "x", "c"]) {
      expect(KEYS).toContain(key);
    }
    expect(keyDown({ key: "q" })).toBeNull();
  });
});
