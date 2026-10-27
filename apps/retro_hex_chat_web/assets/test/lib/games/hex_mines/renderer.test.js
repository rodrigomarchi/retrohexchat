import { describe, expect, it } from "vitest";
import { createEffects } from "../../../../js/lib/games/hex_mines/effects.js";
import { geometryFor, layout } from "../../../../js/lib/games/hex_mines/layout.js";
import { createInitialState } from "../../../../js/lib/games/hex_mines/physics.js";
import { LEVEL } from "../../../../js/lib/games/hex_mines/protocol.js";
import { render } from "../../../../js/lib/games/hex_mines/renderer.js";
import { CELL } from "../../../../js/lib/games/hex_mines/rules.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const NAMES = ["closed", "pressed", "open", "flag", "mine", "boom", "wrong", "dig", "mark"]
  .concat([1, 2, 3, 4, 5, 6, 7, 8].map((n) => `n${n}`))
  .concat(["smile", "wow", "dead", "cool"].map((m) => `face_${m}`))
  .concat([..."0123456789", "minus"].map((d) => `digit_${d}`));
const regions = Object.fromEntries(
  NAMES.map((name, k) => [name, { x: k * 20, y: 0, w: 16, h: 16 }]),
);
const atlas = { image: { id: "tiles" }, regions };
const colors = { back: "b", bar: "r", frame: "f", glow: "g", closed: "c", open: "o" };
const cut = (log, name) =>
  log.filter(([op, , sx]) => op === "drawImage" && sx === regions[name].x).length;

function drawn(id, side, state) {
  const geometry = geometryFor(id)[side];
  const laid = layout(LEVEL[id], geometry);
  const canvas = recordingCanvas(geometry.view.width, geometry.view.height);
  canvas.clearLog();
  render(canvas.getContext("2d"), {
    state: state ?? createInitialState(LEVEL[id]),
    laid,
    fx: createEffects(),
    atlas,
    colors,
    now: 0,
    pressed: null,
  });
  return canvas.log;
}

describe("Hex Mines' picture", () => {
  it("draws every square shut, the smiling face and the mines to find", () => {
    const log = drawn("hex_mines", "LANDSCAPE");
    expect(cut(log, "closed")).toBe(81);
    expect(cut(log, "face_smile")).toBe(1);
    expect(cut(log, "digit_1")).toBe(1);
    expect(cut(log, "dig")).toBe(0);
  });

  it("stands the expert board up with the switch, every square on a whole pixel", () => {
    const log = drawn("hex_mines_expert", "PORTRAIT");
    expect(cut(log, "closed")).toBe(480);
    expect(cut(log, "dig")).toBe(1);
    for (const call of log.filter(([op]) => op === "drawImage")) {
      expect(Number.isInteger(call[6]) && Number.isInteger(call[7])).toBe(true);
    }
  });

  it("shows the mines, the one gone off and the wrong flags once a mine has gone off", () => {
    const state = createInitialState(LEVEL.hex_mines);
    const mine = state.board.cell.map((_, i) => i < 3);
    const cell = state.board.cell.map((_, i) => (i === 1 || i === 5 ? CELL.FLAG : CELL.CLOSED));
    const lost = { ...state, lost: true, board: { ...state.board, mine, cell, boom: 0 } };
    const log = drawn("hex_mines", "LANDSCAPE", lost);
    expect(cut(log, "boom")).toBe(1);
    expect(cut(log, "mine")).toBe(1);
    expect(cut(log, "flag")).toBe(1);
    expect(cut(log, "wrong")).toBe(1);
    expect(cut(log, "face_dead")).toBe(1);
  });
});
