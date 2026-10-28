/**
 * What moves in the well, apart from the match: the rows cleared flashing
 * and bursting into sparks of their gems' colours while the stack above
 * falls into place, the level pulsing as it goes up, a dropped piece's trail and the well's shake, a piece
 * blinking as it locks, and at the end the well going dark from the bottom
 * up (or, for a Sprint run, a burst of sparks).
 *
 * The match changes in the tick (`physics.js`); these only draw it arriving,
 * on the solo core's effects (`core/solo/effects.js`). Any randomness comes
 * from the match's effects stream (`game.fxRandom`). With motion reduced,
 * only the flash is left.
 *
 * @module games/hex_blocks/effects
 */

import { gameColor } from "../../game_colors.js";
import { burst } from "../core/render.js";
import { progress } from "../core/tween.js";
import { cellPlace } from "./layout.js";
import { PIECES } from "./pieces.js";
import { COLS } from "./protocol.js";

export { active, createEffects, shakeAt, stepEffects } from "../core/solo/effects.js";

/** How long each effect lasts, in ticks. */
export const FX = Object.freeze({
  flash: 14,
  settle: 10,
  trail: 10,
  shake: 12,
  blink: 8,
  sparks: 40,
  fade: 90,
  level: 40,
});

/** Each piece's colour as sparks fly: the gem's own, light. */
const SPARK = Object.freeze({
  red: "ff6a80",
  orange: "ffb052",
  yellow: "ffe45a",
  lime: "d0f45a",
  green: "6af09c",
  teal: "62eadc",
  cyan: "72d8ff",
  blue: "8aa0ff",
  violet: "c890ff",
  pink: "ff86e4",
});
const sparkOf = (cell) => gameColor(SPARK[PIECES[cell - 1].colour]);

const centre = (r) => [r.x + r.w / 2, r.y + r.h / 2];

/** Rows cleared: their flash, the stack above settling, and their gems bursting. */
function cleared(fx, { landed, rows, laid, now, random }) {
  fx.list.push({ kind: "flash", rows, start: now, ticks: FX.flash });
  if (fx.reduced) return;
  fx.list.push({ kind: "settle", rows, start: now, ticks: FX.settle });
  for (const r of rows) {
    for (let c = 0; c < COLS; c++) {
      const cell = landed.well.cells[r * COLS + c];
      if (!cell) continue;
      const [x, y] = centre(cellPlace(laid, c, r));
      const particles = burst(
        x,
        y,
        3,
        { speed: [1, 3], extra: () => ({ life: 1, color: sparkOf(cell) }) },
        random,
      );
      fx.list.push({ kind: "sparks", particles, start: now, ticks: FX.sparks });
    }
  }
}

/** A piece set in the well: its trail when it was dropped, its blink, and the rows it cleared. */
function locked(fx, { after, laid, now, random }) {
  const { landed } = after;
  if (landed.trail && !fx.reduced) {
    fx.list.push({ kind: "trail", ...landed.trail, start: now, ticks: FX.trail });
    fx.list.push({ kind: "shake", start: now, ticks: FX.shake });
  }
  if (!fx.reduced) {
    fx.list.push({ kind: "blink", cells: landed.cells, start: now, ticks: FX.blink });
  }
  if (after.cleared.length > 0) cleared(fx, { landed, rows: after.cleared, laid, now, random });
}

/**
 * The effects of an action or a tick, from the match before it to the match
 * after: each read from what changed — a piece set (`landed`), the level,
 * the end — never from the tick's events, which a press in the next tick
 * still carries.
 * @param {object} fx
 * @param {{ before: object, after: object, laid: object, now: number,
 *   random: () => number }} played
 */
export function playedEffects(fx, played) {
  const { before, after, laid, now, random } = played;
  if (after.landed && after.landed !== before.landed) locked(fx, played);
  if (after.level > before.level) fx.list.push({ kind: "level", start: now, ticks: FX.level });
  if (after.over && !before.over && !fx.reduced) {
    fx.list.push({ kind: "fade", start: now, ticks: FX.fade });
  }
  if (after.won && !before.won) {
    const [x, y] = centre(laid.well);
    const particles = burst(
      x,
      y,
      fx.reduced ? 10 : 40,
      {
        speed: [2, 4],
        extra: (k) => ({ life: 1, color: gameColor(Object.values(SPARK)[k % 10]) }),
      },
      random,
    );
    fx.list.push({ kind: "sparks", particles, start: now, ticks: FX.sparks });
  }
}

/** How the rows flashing glow at `now` (0 to 1), and which. */
export function flashAt(fx, now) {
  const flash = fx.list.find((e) => e.kind === "flash");
  if (!flash) return null;
  return { rows: flash.rows, glow: 1 - progress(flash.start, flash.ticks, now) };
}

/** How far a square is still lifted, in rows, as the stack settles: one for each row cleared under it. */
export function settleAt(fx, r, now) {
  const settle = fx.list.find((e) => e.kind === "settle");
  if (!settle) return 0;
  const under = settle.rows.filter((row) => row > r).length;
  return under * (1 - progress(settle.start, settle.ticks, now));
}

/** The squares a piece blinks on as it locks, and how bright (0 to 1). */
export function blinkAt(fx, now) {
  const blink = fx.list.find((e) => e.kind === "blink");
  if (!blink) return null;
  return { cells: blink.cells, glow: 1 - progress(blink.start, blink.ticks, now) };
}

/** A dropped piece's trail: the squares it fell from, the rows it fell, and how faint it is now. */
export function trailAt(fx, now) {
  const trail = fx.list.find((e) => e.kind === "trail");
  if (!trail) return null;
  return {
    cells: trail.cells,
    rows: trail.rows,
    glow: 1 - progress(trail.start, trail.ticks, now),
  };
}

/** How bright the level glows as it goes up (0 to 1): three pulses. */
export function levelAt(fx, now) {
  const pulse = fx.list.find((e) => e.kind === "level");
  if (!pulse) return 0;
  const t = progress(pulse.start, pulse.ticks, now);
  return t >= 1 ? 0 : Math.abs(Math.sin(t * Math.PI * 3));
}

/** How far up the well has gone dark at the end, from 0 (none) to 1 (all of it). */
export function fadeAt(fx, now) {
  const fade = fx.list.find((e) => e.kind === "fade");
  return fade ? progress(fade.start, fade.ticks, now) : 0;
}
