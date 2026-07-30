/**
 * The browser tab title, composed from its two inputs.
 *
 * `document.title` has exactly one owner so the two things that want to write
 * it cannot fight: the *base* title names the current conversation and changes
 * whenever the server re-renders it, while the *flash* is a transient activity
 * cue that alternates on top of it. A base change mid-flash is applied to both
 * halves of the alternation, so stopping the flash never restores a stale name.
 */

/**
 * Creates the document title controller.
 *
 * @param {Object} [options]
 * @param {number} [options.interval=1500] - Flash alternation interval in ms
 * @returns {{ setBase: Function, startFlash: Function, stopFlash: Function, isFlashing: Function }}
 */
export function createDocumentTitle(options = {}) {
  const { interval = 1500 } = options;
  let flashTimer = null;
  let base = document.title;
  let message = null;
  let showingMessage = false;

  function render() {
    document.title = showingMessage && message ? `${message} - ${base}` : base;
  }

  return {
    /**
     * Sets the base title (the conversation name). Applied immediately, and
     * carried into the flash alternation while one is running.
     *
     * @param {string} title - New base title; blank values are ignored
     */
    setBase(title) {
      if (typeof title !== "string" || title.trim() === "") return;
      if (title === base) return;

      base = title;
      render();
    },

    /**
     * Starts alternating the title with an activity message.
     * No-op if already flashing.
     *
     * @param {string} activityMessage - e.g. "* New activity"
     */
    startFlash(activityMessage) {
      if (flashTimer) return;

      message = activityMessage;
      showingMessage = true;
      render();

      flashTimer = setInterval(() => {
        showingMessage = !showingMessage;
        render();
      }, interval);
    },

    /**
     * Stops the flash and leaves the current base title on screen.
     */
    stopFlash() {
      if (!flashTimer) return;

      clearInterval(flashTimer);
      flashTimer = null;
      message = null;
      showingMessage = false;
      render();
    },

    /**
     * @returns {boolean} whether an activity flash is running
     */
    isFlashing() {
      return flashTimer !== null;
    },
  };
}
