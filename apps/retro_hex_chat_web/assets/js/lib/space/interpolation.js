/**
 * Per-remote tile interpolation. Remote avatars snap between whole tiles on the
 * server; the client tweens each move over a short duration so movement reads
 * as a smooth glide instead of a teleport. Retargeting mid-tween starts the new
 * tween from the current sampled position.
 * @module space/interpolation
 */

const DEFAULT_DURATION = 120;

export class Interpolator {
  /** @param {{duration?: number}} [opts] */
  constructor({ duration } = {}) {
    this._duration = duration ?? DEFAULT_DURATION;
    this._tweens = new Map();
  }

  /** Place a key immediately with no animation (snapshot/join). */
  reset(key, x, y) {
    this._tweens.set(key, { fromX: x, fromY: y, toX: x, toY: y, start: 0, done: true });
  }

  /** Start a tween toward (x, y) from the current sampled position. */
  moveTo(key, x, y, now) {
    const current = this.position(key, now) ?? { x, y };
    this._tweens.set(key, {
      fromX: current.x,
      fromY: current.y,
      toX: x,
      toY: y,
      start: now,
      done: false,
    });
  }

  remove(key) {
    this._tweens.delete(key);
  }

  /** @returns {{x:number,y:number}|null} the sampled position at `now`. */
  position(key, now) {
    const tween = this._tweens.get(key);
    if (!tween) return null;
    if (tween.done) return { x: tween.toX, y: tween.toY };

    const t = clamp01((now - tween.start) / this._duration);
    return {
      x: lerp(tween.fromX, tween.toX, t),
      y: lerp(tween.fromY, tween.toY, t),
    };
  }
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

function clamp01(t) {
  if (t < 0) return 0;
  if (t > 1) return 1;
  return t;
}
