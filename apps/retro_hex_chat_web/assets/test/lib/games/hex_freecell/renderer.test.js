import { describe, expect, it } from "vitest";
import { createEffects } from "../../../../js/lib/games/core/card_table/effects.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { createInitialState } from "../../../../js/lib/games/hex_freecell/physics.js";
import { GEOMETRY } from "../../../../js/lib/games/hex_freecell/protocol.js";
import { render } from "../../../../js/lib/games/hex_freecell/renderer.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

const colors = { felt: "f", feltDark: "d", slot: "s", ink: "i", shadow: "sh" };
const region = (i, w, h) => ({ x: i * (w + 2), y: 0, w, h });
const atlas = {
  image: { id: "atlas" },
  card: { width: 64, height: 88 },
  faces: Array.from({ length: 52 }, (_, i) => region(i, 64, 88)),
  backs: [0, 1, 2, 3].map((i) => region(60 + i, 64, 88)),
  mini: {
    card: { width: 44, height: 62 },
    faces: Array.from({ length: 52 }, (_, i) => ({ ...region(i, 44, 62), y: 1000 })),
    backs: [0, 1, 2, 3].map((i) => ({ ...region(60 + i, 44, 62), y: 1000 })),
  },
};

function drawn(geometry, size) {
  const state = createInitialState(createRng(3).next, geometry);
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
  return canvas.log;
}
const images = (log) => log.filter(([op]) => op === "drawImage");

describe("Hex FreeCell's picture", () => {
  it("draws the 52 cards of the deal and the eight empty cells and foundations", () => {
    const log = drawn(GEOMETRY.LANDSCAPE, "full");
    expect(images(log)).toHaveLength(52);
    expect(log.filter(([op]) => op === "strokeRect")).toHaveLength(8);
  });

  it("draws the minis, at their size, on the table standing up", () => {
    const cards = images(drawn(GEOMETRY.PORTRAIT, "mini"));
    expect(cards).toHaveLength(52);
    for (const call of cards) {
      expect(call[3]).toBe(1000);
      expect(call.slice(8)).toEqual([44, 62]);
    }
  });

  it("puts every card on a whole pixel", () => {
    for (const call of images(drawn(GEOMETRY.LANDSCAPE, "full"))) {
      expect(Number.isInteger(call[6]) && Number.isInteger(call[7])).toBe(true);
    }
  });
});
