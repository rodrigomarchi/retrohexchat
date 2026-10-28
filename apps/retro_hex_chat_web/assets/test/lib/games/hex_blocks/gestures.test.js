import { describe, expect, it } from "vitest";
import {
  KEYS,
  createPad,
  keyDown,
  keyUp,
  padEvent,
} from "../../../../js/lib/games/hex_blocks/gestures.js";
import { GEOMETRY, layout } from "../../../../js/lib/games/hex_blocks/layout.js";

const laid = layout(GEOMETRY.PORTRAIT);
const centre = (name) => {
  const r = laid.buttons[name];
  return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
};
const touch = (pad, type, finger, at = {}) => padEvent(pad, laid, { type, finger, ...at });

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

describe("the buttons on the screen", () => {
  it("press a held move with a finger, and release it when the finger lifts", () => {
    let pad = createPad();
    let out = touch(pad, "down", 0, centre("left"));
    expect(out.actions).toEqual([{ type: "press", input: "left" }]);
    pad = out.pad;
    out = touch(pad, "move", 0, centre("left"));
    expect(out.actions).toEqual([]);
    out = touch(out.pad, "up", 0, centre("left"));
    expect(out.actions).toEqual([{ type: "release", input: "left" }]);
  });

  it("follow two fingers at once: holding left and turning", () => {
    let { pad, actions } = touch(createPad(), "down", 0, centre("left"));
    expect(actions).toEqual([{ type: "press", input: "left" }]);
    ({ pad, actions } = touch(pad, "down", 1, centre("turn_cw")));
    expect(actions).toEqual([{ type: "turn", dir: 1 }]);
    ({ pad, actions } = touch(pad, "up", 1, centre("turn_cw")));
    expect(actions).toEqual([]);
    expect(touch(pad, "up", 0, centre("left")).actions).toEqual([
      { type: "release", input: "left" },
    ]);
  });

  it("act at once on the press: drop, hold and both turns", () => {
    const at = (name) => touch(createPad(), "down", 0, centre(name)).actions;
    expect(at("drop")).toEqual([{ type: "drop" }]);
    expect(at("hold")).toEqual([{ type: "hold" }]);
    expect(at("turn_ccw")).toEqual([{ type: "turn", dir: -1 }]);
    expect(at("down")).toEqual([{ type: "press", input: "down" }]);
  });

  it("release a held move when the finger slides off its button, or is taken away", () => {
    let { pad } = touch(createPad(), "down", 0, centre("right"));
    const off = touch(pad, "move", 0, { x: 2, y: 2 });
    expect(off.actions).toEqual([{ type: "release", input: "right" }]);
    expect(touch(off.pad, "up", 0, { x: 2, y: 2 }).actions).toEqual([]);
    ({ pad } = touch(createPad(), "down", 0, centre("down")));
    expect(touch(pad, "cancel", 0).actions).toEqual([{ type: "release", input: "down" }]);
  });

  it("keeps a move held while another finger is still on its button", () => {
    let { pad } = touch(createPad(), "down", 0, centre("left"));
    ({ pad } = touch(pad, "down", 1, centre("left")));
    const lifted = touch(pad, "up", 0, centre("left"));
    expect(lifted.actions).toEqual([]);
    expect(touch(lifted.pad, "up", 1, centre("left")).actions).toEqual([
      { type: "release", input: "left" },
    ]);
  });

  it("does nothing for a press off the buttons", () => {
    const r = laid.well;
    const out = touch(createPad(), "down", 0, { x: r.x + 5, y: r.y + 5 });
    expect(out.actions).toEqual([]);
    expect(touch(out.pad, "up", 0, { x: r.x + 5, y: r.y + 5 }).actions).toEqual([]);
  });

  it("names which buttons are held down, to draw them so", () => {
    const { pad } = touch(createPad(), "down", 3, centre("left"));
    expect([...pad.values()]).toEqual(["left"]);
  });
});
