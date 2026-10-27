/**
 * What moves over a one-player board game's squares, apart from the match:
 * a piece dropping in with a hop, a shake (of the whole board, or of one
 * square), a square's glow, and sparks that fly and fade. A game pushes its
 * effects onto `fx.list` — `{ kind, start, ticks, i? }`, and `particles` for
 * sparks — and reads them back while drawing.
 *
 * Each is measured in ticks from the tick it began; with motion reduced, a
 * game pushes fewer of them.
 *
 * @module games/core/solo/effects
 */

import { stepParticles } from "../render.js";
import { progress } from "../tween.js";

/** The effects of one match. */
export const createEffects = ({ reduced = false } = {}) => ({ reduced, list: [] });

/** One tick of the effects: sparks fly and fade over their `ticks`; the others end on time. */
export function stepEffects(fx, now) {
  fx.list = fx.list.filter((effect) => {
    if (effect.particles) {
      effect.particles = stepParticles(effect.particles, { drag: 0.92, fade: 1 / effect.ticks });
      return effect.particles.length > 0;
    }
    return now < effect.start + effect.ticks;
  });
}

/** Whether anything still moves, so a frame is worth drawing. */
export const active = (fx) => fx.list.length > 0;

/** How far a piece dropping in on square `i` sits above it at `now`, on whole pixels. */
export function hopAt(fx, i, now, height = 6) {
  const hop = fx.list.find((e) => e.kind === "hop" && e.i === i);
  if (!hop) return 0;
  const t = progress(hop.start, hop.ticks, now);
  return -Math.round(Math.sin(t * Math.PI) * height);
}

/** How far the board — or, given `i`, square `i` — is pushed sideways while it shakes. */
export function shakeAt(fx, now, { i, amplitude = 4 } = {}) {
  const shake = fx.list.find((e) => e.kind === "shake" && e.i === i);
  if (!shake) return 0;
  const t = progress(shake.start, shake.ticks, now);
  return Math.round(Math.sin(t * Math.PI * 8) * amplitude * (1 - t));
}

/** How bright square `i` glows at `now` (0 to 1). */
export function glowAt(fx, i, now) {
  const glow = fx.list.find((e) => e.kind === "glow" && e.i === i && now >= e.start);
  if (!glow) return 0;
  return Math.sin(progress(glow.start, glow.ticks, now) * Math.PI);
}
