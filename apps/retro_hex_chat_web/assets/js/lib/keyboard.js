/**
 * Input key classification for chat input navigation.
 *
 * Maps raw keyboard events to semantic actions, decoupling the hook
 * from the specific key bindings so the logic is testable and the
 * action names are self-documenting.
 */

/**
 * Classifies a keydown event on the chat input into a semantic action.
 *
 * @param {string} key - The KeyboardEvent.key value
 * @returns {"history_up"|"history_down"|"tab_complete"|null}
 *   The action to perform, or null if the key has no special meaning
 */
export function classifyInputKey(key) {
  switch (key) {
    case "ArrowUp":
      return "history_up";
    case "ArrowDown":
      return "history_down";
    case "Tab":
      return "tab_complete";
    default:
      return null;
  }
}
