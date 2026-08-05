/**
 * Fixed-timestep clock for host-authoritative game loops.
 *
 * Game physics is expressed in units per step (`PADDLE_SPEED = 6` means six
 * pixels per step). Driving those steps straight off `requestAnimationFrame`
 * ties the simulation to the display: a 120 Hz panel runs the match at double
 * speed and a throttled tab runs it in slow motion. This clock decouples them —
 * a step is always 1/60 s of wall time, however often the browser paints.
 *
 * @module games/frame_clock
 */

/** Duration of one simulation step, in milliseconds. */
export const FIXED_STEP_MS = 1000 / 60;

/**
 * How many steps a single frame may run to catch up. Beyond this the backlog is
 * discarded rather than replayed: a tab that was hidden for a minute must not
 * fast-forward the match through 3600 steps when it comes back.
 */
export const MAX_CATCHUP_STEPS = 5;

export class FrameClock {
  /**
   * @param {object} [options]
   * @param {number} [options.stepMs] - Simulation step duration.
   * @param {number} [options.maxCatchUpSteps] - Catch-up ceiling per frame.
   */
  constructor({ stepMs = FIXED_STEP_MS, maxCatchUpSteps = MAX_CATCHUP_STEPS } = {}) {
    this.stepMs = stepMs;
    this.maxCatchUpSteps = maxCatchUpSteps;
    this.droppedSteps = 0;
    this.stallCount = 0;
    this._accumulator = 0;
    this._lastTime = null;
  }

  /**
   * Anchor the clock to a wall-clock reading without producing steps.
   * @param {number} now
   * @returns {void}
   */
  reset(now) {
    this._accumulator = 0;
    this._lastTime = Number.isFinite(now) ? now : null;
  }

  /**
   * Advance to `now` and report how many simulation steps are owed.
   * @param {number} now - Monotonic timestamp in milliseconds.
   * @returns {number} steps to run this frame
   */
  advance(now) {
    if (!Number.isFinite(now)) return 0;

    if (this._lastTime === null) {
      this._lastTime = now;
      return 0;
    }

    const elapsed = Math.max(0, now - this._lastTime);
    this._lastTime = now;
    this._accumulator += elapsed;

    const budget = this.stepMs * this.maxCatchUpSteps;

    if (this._accumulator > budget) {
      this.droppedSteps += Math.floor((this._accumulator - budget) / this.stepMs);
      this.stallCount += 1;
      this._accumulator = budget;
    }

    const steps = Math.floor(this._accumulator / this.stepMs);
    this._accumulator -= steps * this.stepMs;
    return steps;
  }

  /**
   * Fraction of the next step already elapsed, for render-time smoothing.
   * @returns {number} 0..1
   */
  get alpha() {
    return this._accumulator / this.stepMs;
  }

  /**
   * Consume the accumulated stall counters, resetting them.
   * @returns {{droppedSteps: number, stallCount: number}}
   */
  drainStalls() {
    const drained = { droppedSteps: this.droppedSteps, stallCount: this.stallCount };
    this.droppedSteps = 0;
    this.stallCount = 0;
    return drained;
  }
}
