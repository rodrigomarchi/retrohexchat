import { expect, it } from "vitest";
import { createEffects } from "../../../js/lib/games/core/card_table/effects.js";
import { recordingCanvas } from "./recording_canvas.js";

/**
 * What the tests of the card games share: a card by its rank and suit, an
 * atlas that cuts every face and back at a place of its own, and a table
 * drawn on a recording canvas.
 */

export const S = 0; // spades
export const H = 1; // hearts
export const D = 2; // diamonds
export const C = 3; // clubs

/** A card by its rank (1 ace … 13 king), its suit and, for two decks, its copy. */
export const card = (rank, suit, copy = 0) => copy * 52 + suit * 13 + rank - 1;

/** The colours of the felt, each named after its part. */
export const TABLE_COLORS = Object.freeze({
  felt: "f",
  feltDark: "d",
  slot: "s",
  ink: "i",
  shadow: "sh",
});

const region = (i, w, h, y = 0) => ({ x: i * (w + 2), y, w, h });

/**
 * An atlas of full cards on row 0 and minis on row 1000, each face `i` at
 * `i * (width + 2)` and the four backs from 60 on, so a cut says which it was.
 */
export const TEST_ATLAS = Object.freeze({
  image: { id: "atlas" },
  card: { width: 64, height: 88 },
  faces: Array.from({ length: 52 }, (_, i) => region(i, 64, 88)),
  backs: [0, 1, 2, 3].map((i) => region(60 + i, 64, 88)),
  mini: {
    card: { width: 44, height: 62 },
    faces: Array.from({ length: 52 }, (_, i) => region(i, 44, 62, 1000)),
    backs: [0, 1, 2, 3].map((i) => region(60 + i, 44, 62, 1000)),
  },
});

/**
 * The canvas log of `render` drawing a table of `view`'s size: at rest, cut
 * from the test atlas, unless `scene` says otherwise.
 */
export function drawnTable(render, view, scene) {
  const canvas = recordingCanvas(view.width, view.height);
  canvas.clearLog();
  render(canvas.getContext("2d"), {
    fx: createEffects(),
    drag: null,
    atlas: TEST_ATLAS,
    colors: TABLE_COLORS,
    now: 0,
    back: 0,
    ...scene,
  });
  return canvas.log;
}

/** The cards a canvas log cut from an atlas. */
export const images = (log) => log.filter(([op]) => op === "drawImage");

/** Every card cut from the minis' row of the test atlas, at a mini's size. */
export function expectMinis(cuts) {
  for (const call of cuts) {
    expect(call[3]).toBe(1000);
    expect(call.slice(8)).toEqual([44, 62]);
  }
}

/** A match of `play`'s in a box taller than wide: the table `geometry.PORTRAIT`, dealt in minis. */
export function itStandsUpWithMinis(play, geometry) {
  it("stands the table up with the minis in a box taller than wide", async () => {
    const match = await play({ rect: { left: 0, top: 0, width: 360, height: 600 } });
    match.advance(100);
    const { host } = match.engines;
    expect(host.view).toEqual(geometry.PORTRAIT.view);
    expect(host.fx.card).toEqual({ width: 44, height: 62 });
  });
}
