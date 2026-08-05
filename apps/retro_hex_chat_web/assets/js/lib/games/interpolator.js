/**
 * Snapshot interpolation for the guest side of a host-authoritative game.
 *
 * The guest holds no simulation: it draws whatever the host last told it. Drawn
 * straight, that means motion advances only when a packet lands — the guest's
 * effective frame rate becomes the host's send rate, and every jitter spike is
 * a visible stutter. Interpolation decouples the two: incoming snapshots become
 * targets, and the guest walks the drawn values toward them across real time,
 * so it renders smoothly at display rate off a much slower packet stream.
 *
 * The cost is one interval of added latency, which is why only the guest does
 * this and only for values that read as motion.
 *
 * @module games/interpolator
 */

/** Inter-arrival estimates outside this band are treated as noise. */
const MIN_INTERVAL_MS = 8;
const MAX_INTERVAL_MS = 250;

/** Weight of the newest inter-arrival sample in the interval estimate. */
const INTERVAL_SMOOTHING = 0.2;

/** Default interval before any two snapshots have been seen. */
const INITIAL_INTERVAL_MS = 1000 / 30;

/**
 * Distance beyond which a value is teleporting rather than moving, and must be
 * snapped. Interpolating a ball reset across the court would draw it sliding
 * back through the field it just left.
 */
const DEFAULT_SNAP_DISTANCE = 120;

export class SnapshotInterpolator {
  /**
   * @param {object} [options]
   * @param {string[]} [options.keys] - Numeric state keys that represent motion.
   * @param {number} [options.snapDistance] - Jump size treated as a teleport.
   */
  constructor({ keys = [], snapDistance = DEFAULT_SNAP_DISTANCE } = {}) {
    this.keys = keys;
    this.snapDistance = snapDistance;
    this.intervalMs = INITIAL_INTERVAL_MS;
    this._from = null;
    this._to = null;
    this._startedAt = 0;
    this._lastArrivalAt = null;
  }

  /** @returns {boolean} whether this game declared anything to interpolate */
  get enabled() {
    return this.keys.length > 0;
  }

  /**
   * Forget any in-flight interpolation, keeping the learned interval.
   * @returns {void}
   */
  reset() {
    this._from = null;
    this._to = null;
    this._lastArrivalAt = null;
  }

  /**
   * Capture the values currently on screen, before a snapshot overwrites them.
   * @param {object} displayed - The state object the renderer reads.
   * @returns {Record<string, number>}
   */
  capture(displayed) {
    const captured = {};
    for (const key of this.keys) {
      const value = displayed[key];
      if (typeof value === "number") captured[key] = value;
    }
    return captured;
  }

  /**
   * Record an authoritative snapshot as the new interpolation target.
   *
   * `captured` holds the values as they were drawn, not the previous snapshot —
   * starting from the drawn values is what keeps a late packet from rewinding
   * the picture. `displayed` has already been updated to the authoritative
   * values by the caller, so the targets are read from there.
   *
   * @param {Record<string, number>} captured - Output of `capture()`.
   * @param {object} displayed - State object, already holding the new values.
   * @param {number} now - Arrival timestamp in milliseconds.
   * @returns {void}
   */
  ingest(captured, displayed, now) {
    if (!this.enabled) return;

    if (this._lastArrivalAt !== null) {
      const gap = now - this._lastArrivalAt;
      if (gap >= MIN_INTERVAL_MS && gap <= MAX_INTERVAL_MS) {
        this.intervalMs = this.intervalMs * (1 - INTERVAL_SMOOTHING) + gap * INTERVAL_SMOOTHING;
      }
    }

    this._lastArrivalAt = now;
    this._startedAt = now;

    const from = {};
    const to = {};

    for (const key of this.keys) {
      const target = displayed[key];
      if (typeof target !== "number") continue;

      const start = captured[key];
      if (typeof start !== "number") continue;

      // A teleport, not motion: leave the authoritative value in place rather
      // than sliding the ball back through the field it just left.
      if (Math.abs(target - start) > this.snapDistance) continue;

      from[key] = start;
      to[key] = target;
    }

    this._from = from;
    this._to = to;
  }

  /**
   * Write the interpolated values into the state the renderer reads.
   * @param {object} displayed
   * @param {number} now
   * @returns {boolean} true while the target has not been reached
   */
  apply(displayed, now) {
    if (!this.enabled || !this._to) return false;

    const duration = Math.max(MIN_INTERVAL_MS, this.intervalMs);
    const alpha = Math.min(1, Math.max(0, (now - this._startedAt) / duration));

    for (const key of Object.keys(this._to)) {
      const from = this._from[key];
      const to = this._to[key];
      displayed[key] = from + (to - from) * alpha;
    }

    if (alpha >= 1) {
      this._from = null;
      this._to = null;
      return false;
    }

    return true;
  }
}
