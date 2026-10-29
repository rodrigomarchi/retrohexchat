/**
 * What moves on the board, apart from the match: squares opening in a wave
 * out from the one pressed, a flag dropping in with a hop, a mine going off
 * (sparks of fire and the board shaking), and the flags of a win lighting one
 * after another.
 *
 * The match changes in the tick (`physics.js`); these only draw it arriving.
 * Each is measured in ticks from the tick it began; any randomness comes from
 * the match's effects stream (`game.fxRandom`). With motion reduced, squares
 * open at once and nothing shakes.
 *
 * @module games/hex_mines/effects
 */

export {
  active,
  createEffects,
  glowAt,
  hopAt,
  shakeAt,
  stepEffects,
} from "../core/solo/effects.js";

import { gameColor } from "../../game_colors.js";
import { burstFrom } from "../core/solo/effects.js";
import { boardPlace } from "./layout.js";
import { EVENT } from "./protocol.js";
import { CELL } from "./rules.js";

/** How long each effect lasts, in ticks. */
export const FX = Object.freeze({ ring: 2, hop: 10, shake: 16, fire: 40, winLight: 100, glow: 24 });

/** Squares opened, in rings out from the first: each shows shut until its ring's turn. */
function wave(fx, opened, now) {
  if (fx.reduced || opened.length < 2) return;
  fx.list.push({
    kind: "wave",
    rings: new Map(opened.map(({ i, ring }) => [i, ring])),
    start: now,
    ticks: Math.max(...opened.map((o) => o.ring)) * FX.ring + 1,
  });
}

const FIRE = ["ff5a1f", "ffd34d", "fff6c8", "c51316"];

/**
 * The effects of what a tick did to the board, from its state before to its
 * state after, and the squares it opened.
 * @param {object} fx
 * @param {{ before: object, after: object, laid: object, now: number,
 *   random: () => number }} played - the states before and after (its `opened`, the squares opened)
 */
export function boardEffects(fx, { before, after, laid, now, random }) {
  const { opened } = after;
  const events = after.events & ~before.events;
  if (events & (EVENT.OPEN | EVENT.FLOOD | EVENT.BOOM)) wave(fx, opened, now);
  if (events & EVENT.FLAG && !fx.reduced) {
    const i = after.board.cell.findIndex(
      (c, k) => c === CELL.FLAG && before.board.cell[k] !== CELL.FLAG,
    );
    if (i >= 0) fx.list.push({ kind: "hop", i, start: now, ticks: FX.hop });
  }
  if (events & EVENT.BOOM) {
    burstFrom(fx, boardPlace(laid, after.board.boom), {
      count: fx.reduced ? 8 : 28,
      speed: [2, 3],
      color: (k) => gameColor(FIRE[k % FIRE.length]),
      now,
      ticks: FX.fire,
      random,
      kind: "fire",
    });
    if (!fx.reduced) fx.list.push({ kind: "shake", start: now, ticks: FX.shake });
  }
  if (events & EVENT.WIN && !fx.reduced) {
    const mines = after.board.cell.flatMap((c, i) => (after.board.mine[i] ? [i] : []));
    mines.forEach((i, k) => {
      // Every flag lights within `winLight` ticks, however many mines.
      const stagger = Math.max(1, Math.floor(FX.winLight / mines.length));
      fx.list.push({ kind: "glow", i, start: now + k * stagger, ticks: FX.glow });
    });
  }
}

/** Whether square `i` still shows shut while the wave reaches it. */
export function waiting(fx, i, now) {
  return fx.list.some(
    (e) => e.kind === "wave" && e.rings.has(i) && now < e.start + e.rings.get(i) * FX.ring,
  );
}
