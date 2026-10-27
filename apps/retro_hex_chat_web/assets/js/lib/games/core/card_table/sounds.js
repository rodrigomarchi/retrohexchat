/**
 * A card table's sounds, as data the core's synthesizer plays: short 8-bit
 * clicks and chimes, one for each thing that happens on the table.
 * @module games/core/card_table/sounds
 */

import { fade, glide } from "../synth.js";

export const MASTER_VOLUME = 0.25;

/** A square note that rings out, `delay` seconds in. */
const note = (freq, dur, vol, delay = 0) => ({
  wave: "square",
  freq,
  vol: fade(vol, dur, "exp"),
  dur,
  delay,
});

/** A card's snap: a little noise and a low knock. */
const snap = (vol) => [
  { wave: "noise", vol: fade(vol, 0.03, "exp"), dur: 0.03 },
  { wave: "triangle", freq: 180, vol: fade(vol, 0.05, "exp"), dur: 0.05 },
];

export const SOUNDS = {
  /** The deal: a riffle of quick snaps. */
  deal: Array.from({ length: 8 }, (_, i) => ({
    wave: "noise",
    vol: fade(0.08, 0.025, "exp"),
    dur: 0.025,
    delay: i * 0.05,
  })),
  /** A card turned from the stock. */
  draw: snap(0.08),
  /** A card turned over on the table: a rising flick. */
  flip: { wave: "square", freq: glide(500, 900, 0.05), vol: fade(0.06, 0.05, "exp"), dur: 0.05 },
  /** Cards laid on a column. */
  place: snap(0.1),
  /** A card up on its foundation: a bright two-note chime. */
  foundation: [note(1046, 0.08, 0.08), note(1568, 0.12, 0.08, 0.06)],
  /** A move with nowhere to go: a low buzz. */
  refuse: { wave: "square", freq: 110, vol: fade(0.08, 0.12, "exp"), dur: 0.12 },
  /** The waste turned back into the stock: a falling sweep. */
  recycle: { wave: "square", freq: glide(700, 200, 0.18), vol: fade(0.06, 0.18, "exp"), dur: 0.18 },
  /** A card going back where it was picked up. */
  return: snap(0.05),
  /** The table cleared: a fanfare climbing up. */
  win: [523, 659, 784, 1046, 784, 1046, 1318].map((freq, i) => note(freq, 0.14, 0.1, i * 0.12)),
};
