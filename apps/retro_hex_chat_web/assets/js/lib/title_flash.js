/**
 * Title bar flash logic for activity notifications.
 *
 * Creates a title flasher that alternates the browser tab title between
 * the original title and an activity message, providing a visual cue
 * for unread activity in non-active channels or PMs.
 */

/**
 * Creates a title flasher instance.
 *
 * The flasher alternates the document title between the original and
 * an activity message at a configurable interval. It auto-captures
 * the current title when starting and restores it when stopping.
 *
 * @param {Object} [options]
 * @param {number} [options.interval=1500] - Flash interval in milliseconds
 * @returns {{ start: Function, stop: Function, isFlashing: Function }}
 */
export function createTitleFlasher(options = {}) {
  const { interval = 1500 } = options;
  let flashTimer = null;
  let savedTitle = "";

  return {
    /**
     * Starts flashing the title with the given activity message.
     * No-op if already flashing.
     *
     * @param {string} message - Activity message (e.g., "* New activity")
     */
    start(message) {
      if (flashTimer) return;

      savedTitle = document.title;
      let showActivity = true;

      flashTimer = setInterval(() => {
        document.title = showActivity ? `${message} - RetroHexChat` : savedTitle;
        showActivity = !showActivity;
      }, interval);
    },

    /**
     * Stops flashing and restores the original title.
     */
    stop() {
      if (flashTimer) {
        clearInterval(flashTimer);
        flashTimer = null;
        document.title = savedTitle;
      }
    },

    /**
     * Returns whether the title is currently flashing.
     * @returns {boolean}
     */
    isFlashing() {
      return flashTimer !== null;
    },
  };
}
