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

import { gameColor } from "../../game_colors.js";
import { burst, stepParticles } from "../core/render.js";
import { progress } from "../core/tween.js";
import { boardPlace } from "./layout.js";
import { EVENT } from "./protocol.js";
import { CELL } from "./rules.js";

/** How long each effect lasts, in ticks. */
export const FX = Object.freeze({ ring: 2, hop: 10, shake: 16, fire: 40, winStagger: 3, glow: 24 });

/** The effects of one match. */
export const createEffects = ({ reduced = false } = {}) => ({ reduced, list: [] });

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
    const at = boardPlace(laid, after.board.boom);
    const particles = burst(
      at.x + at.w / 2,
      at.y + at.h / 2,
      fx.reduced ? 8 : 28,
      { speed: [2, 3], extra: (k) => ({ life: 1, color: gameColor(FIRE[k % FIRE.length]) }) },
      random,
    );
    fx.list.push({ kind: "fire", particles, start: now, ticks: FX.fire });
    if (!fx.reduced) fx.list.push({ kind: "shake", start: now, ticks: FX.shake });
  }
  if (events & EVENT.WIN && !fx.reduced) {
    const mines = after.board.cell.flatMap((c, i) => (after.board.mine[i] ? [i] : []));
    mines.forEach((i, k) => {
      fx.list.push({ kind: "glow", i, start: now + k * FX.winStagger, ticks: FX.glow });
    });
  }
}

/** One tick of the effects: the fire flies and fades; the others end on time. */
export function stepEffects(fx, now) {
  fx.list = fx.list.filter((effect) => {
    if (effect.kind === "fire") {
      effect.particles = stepParticles(effect.particles, { drag: 0.92, fade: 1 / FX.fire });
      return effect.particles.length > 0;
    }
    return now < effect.start + effect.ticks;
  });
}

/** Whether anything still moves, so a frame is worth drawing. */
export const active = (fx) => fx.list.length > 0;

/** Whether square `i` still shows shut while the wave reaches it. */
export function waiting(fx, i, now) {
  return fx.list.some(
    (e) => e.kind === "wave" && e.rings.has(i) && now < e.start + e.rings.get(i) * FX.ring,
  );
}

/** How far a flag dropping in sits above its square at `now`, on whole pixels. */
export function hopAt(fx, i, now) {
  const hop = fx.list.find((e) => e.kind === "hop" && e.i === i);
  if (!hop) return 0;
  const t = progress(hop.start, hop.ticks, now);
  return -Math.round(Math.sin(t * Math.PI) * 6);
}

/** How far the board is pushed sideways while it shakes. */
export function shakeAt(fx, now) {
  const shake = fx.list.find((e) => e.kind === "shake");
  if (!shake) return 0;
  const t = progress(shake.start, shake.ticks, now);
  return Math.round(Math.sin(t * Math.PI * 8) * 4 * (1 - t));
}

/** How bright a win's flag glows at `now` (0 to 1). */
export function glowAt(fx, i, now) {
  const glow = fx.list.find((e) => e.kind === "glow" && e.i === i);
  if (!glow || now < glow.start) return 0;
  return Math.sin(progress(glow.start, glow.ticks, now) * Math.PI);
}
