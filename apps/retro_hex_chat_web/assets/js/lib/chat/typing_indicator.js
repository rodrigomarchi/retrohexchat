/**
 * The PM typing indicator — a small state machine, no LiveView.
 *
 * The first keystroke starts typing; a lull of `delayMs` stops it. Start and
 * stop are reported through ports; the timer is injectable so a test drives it
 * with a fake clock.
 *
 * @module chat/typing_indicator
 */

export const TYPING_STOP_DELAY_MS = 3000;

/**
 * @param {object} ports
 * @param {() => void} ports.onStart
 * @param {() => void} ports.onStop
 * @param {number} [ports.delayMs]
 * @param {typeof setTimeout} [ports.setTimeoutFn]
 * @param {typeof clearTimeout} [ports.clearTimeoutFn]
 */
export function createTypingIndicator({
  onStart,
  onStop,
  delayMs = TYPING_STOP_DELAY_MS,
  setTimeoutFn,
  clearTimeoutFn,
}) {
  const arm = (fn) => (setTimeoutFn || setTimeout)(fn, delayMs);
  const disarm = (timer) => (clearTimeoutFn || clearTimeout)(timer);

  let active = false;
  let timer = null;

  return {
    get active() {
      return active;
    },

    /** A keystroke: start typing if idle, and (re)arm the stop timer. */
    keystroke() {
      if (!active) {
        active = true;
        onStart();
      }
      if (timer) disarm(timer);
      timer = arm(() => {
        active = false;
        timer = null;
        onStop();
      });
    },

    /** Stop now (submit, clear): report a stop only if currently typing. */
    stop() {
      if (timer) {
        disarm(timer);
        timer = null;
      }
      if (active) {
        active = false;
        onStop();
      }
    },
  };
}
