/**
 * A touch long-press gesture, minus what any one caller does with it.
 *
 * Three hooks — the nicklist, the conversations sidebar and the chat viewport —
 * open a context menu on a held touch. The mechanics were identical in all
 * three: arm a timer on pointerdown, cancel it if the finger drifts past a
 * tolerance, fire once, and suppress the click that a lift would otherwise
 * synthesise. Only the target detection and what happens on fire differed, and
 * those stay in the caller as `onFire` (and, where a caller must re-check the
 * target at fire time, `shouldFire`).
 *
 * Timers are injectable so the machine can be driven by a fake clock in a test.
 *
 * @module input/long_press
 */

export const LONG_PRESS_MS = 550;
export const MOVE_TOLERANCE_PX = 10;

/**
 * @param {object} options
 * @param {number} [options.thresholdMs] hold time before it fires
 * @param {number} [options.tolerancePx] drift allowed before it cancels
 * @param {(context: any) => void} options.onFire called once when the press fires
 * @param {(context: any) => boolean} [options.shouldFire] re-check at fire time;
 *   returning false cancels instead of firing (e.g. the target left the DOM)
 * @param {typeof setTimeout} [options.setTimeoutFn]
 * @param {typeof clearTimeout} [options.clearTimeoutFn]
 * @returns {{
 *   start(x: number, y: number, context?: any): void,
 *   move(x: number, y: number): void,
 *   finish(): boolean,
 *   cancel(options?: { keepClickSuppression?: boolean }): void,
 *   readonly active: boolean,
 *   readonly fired: boolean,
 *   suppressNextClick: boolean,
 *   consumeClickSuppression(): boolean,
 * }}
 */
export function createLongPress({
  thresholdMs = LONG_PRESS_MS,
  tolerancePx = MOVE_TOLERANCE_PX,
  onFire,
  shouldFire,
  setTimeoutFn,
  clearTimeoutFn,
}) {
  let state = null;
  let suppressNextClick = false;

  // Resolved at call time, not construction: a test that flips on fake timers
  // after the machine is built (as a hook mounting in beforeEach does) still
  // gets the faked global, exactly as the inline setTimeout used to.
  const arm = (fn) => (setTimeoutFn || setTimeout)(fn, thresholdMs);
  const disarm = (timer) => (clearTimeoutFn || clearTimeout)(timer);

  const machine = {
    start(x, y, context) {
      this.cancel();
      state = {
        x,
        y,
        context,
        fired: false,
        timer: arm(() => {
          if (!state) return;
          if (shouldFire && !shouldFire(state.context)) {
            this.cancel();
            return;
          }
          state.fired = true;
          suppressNextClick = true;
          onFire(state.context);
        }),
      };
    },

    move(x, y) {
      if (!state || state.fired) return;
      if (Math.abs(x - state.x) > tolerancePx || Math.abs(y - state.y) > tolerancePx) {
        this.cancel();
      }
    },

    finish() {
      const fired = Boolean(state?.fired);
      this.cancel({ keepClickSuppression: true });
      return fired;
    },

    cancel({ keepClickSuppression = false } = {}) {
      if (state?.timer) disarm(state.timer);
      state = null;
      if (!keepClickSuppression) suppressNextClick = false;
    },

    get active() {
      return state !== null;
    },

    get fired() {
      return Boolean(state?.fired);
    },

    get suppressNextClick() {
      return suppressNextClick;
    },

    set suppressNextClick(value) {
      suppressNextClick = value;
    },

    consumeClickSuppression() {
      const suppressed = suppressNextClick;
      suppressNextClick = false;
      return suppressed;
    },
  };

  return machine;
}
