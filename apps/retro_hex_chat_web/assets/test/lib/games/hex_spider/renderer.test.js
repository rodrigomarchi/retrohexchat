import { describe, expect, it } from "vitest";
import { createEffects } from "../../../../js/lib/games/core/card_table/effects.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { createInitialState } from "../../../../js/lib/games/hex_spider/physics.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_spider/protocol.js";
import { render } from "../../../../js/lib/games/hex_spider/renderer.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const colors = { felt: "f", feltDark: "d", slot: "s", ink: "i", shadow: "sh" };
const region = (i, w, h, y = 0) => ({ x: i * (w + 2), y, w, h });
const atlas = {
  image: { id: "atlas" },
  card: { width: 64, height: 88 },
  faces: Array.from({ length: 52 }, (_, i) => region(i, 64, 88)),
  backs: [0, 1, 2, 3].map((i) => region(60 + i, 64, 88)),
  mini: {
    card: { width: 44, height: 62 },
    faces: Array.from({ length: 52 }, (_, i) => region(i, 44, 62, 1000)),
    backs: [0, 1, 2, 3].map((i) => region(60 + i, 44, 62, 1000)),
  },
};

function drawn(geometry, size, suits = 4) {
  const state = createInitialState(createRng(3).next, suits, geometry);
  const canvas = recordingCanvas(geometry.view.width, geometry.view.height);
  canvas.clearLog();
  render(canvas.getContext("2d"), {
    state,
    fx: createEffects({ size }),
    drag: null,
    atlas,
    colors,
    now: 0,
    back: 0,
  });
  return { state, log: canvas.log.filter(([op]) => op === "drawImage") };
}

describe("Hex Spider's picture", () => {
  it("draws the 54 cards dealt and a back for each of the five deals left", () => {
    expect(drawn(GEOMETRY.LANDSCAPE, "full").log).toHaveLength(59);
  });

  it("cuts each card's face, the same for two cards alike", () => {
    const { state, log } = drawn(GEOMETRY.LANDSCAPE, "full", 1);
    const tops = state.table.columns.map((c) => c.up[0]);
    const faces = log.filter((call) => call[2] < 60 * 66).map((call) => call[2] / 66);
    for (const top of tops) expect(faces).toContain(top % 52);
  });

  it("draws the minis, at their size, on the table standing up", () => {
    for (const call of drawn(GEOMETRY.PORTRAIT, "mini").log) {
      expect(call[3]).toBe(1000);
      expect(call.slice(8)).toEqual([44, 62]);
    }
  });
});
