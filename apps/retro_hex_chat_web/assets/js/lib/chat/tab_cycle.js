/**
 * Tab-completion cycling machine.
 *
 * When the server answers a `tab_complete` with its matches, the machine writes
 * the first match into the textarea and remembers the list so the next Tab can
 * advance through it. The suffix mirrors the server contract: ": " after a
 * line-start nick, " " otherwise.
 *
 * Writing reflects a synthetic "input" event back into the field. The host's own
 * input listener treats that echo as a keystroke and calls `reset()`, so the
 * machine re-reads its remembered state on the next tick (`setTimeout(0)`) to
 * survive its own echo. `preserved` is captured *after* the dispatch — exactly
 * as the original hook did — so the ordering is byte-for-byte identical to the
 * code this replaced.
 */

/**
 * @param {HTMLTextAreaElement|HTMLInputElement} el - the composer input
 * @param {{setTimeoutFn?: Function}} [ports]
 * @returns {{active: boolean, start: Function, advance: Function, reset: Function}}
 */
export function createTabCycle(el, { setTimeoutFn } = {}) {
  let state = null;

  function write() {
    const match = state.matches[state.index];
    const suffix = state.isStart ? ": " : " ";
    el.value = match + suffix;
    el.dispatchEvent(new Event("input", { bubbles: true }));
    const preserved = state;
    (setTimeoutFn || setTimeout)(() => {
      state = preserved;
    }, 0);
  }

  return {
    get active() {
      return state !== null;
    },

    start(matches, isStart) {
      if (!matches || matches.length === 0) return;
      state = { original: el.value, matches, index: 0, isStart };
      write();
    },

    advance() {
      if (!state) return;
      state.index = (state.index + 1) % state.matches.length;
      write();
    },

    reset() {
      state = null;
    },
  };
}
