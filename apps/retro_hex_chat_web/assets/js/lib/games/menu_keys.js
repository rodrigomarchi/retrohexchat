/**
 * When the menu over a running match is asked for: Esc, heard before the game
 * engine's own capture listener (which keeps every key of a running match
 * from going further — so this must be attached first), and, where the match
 * can be held, the tab put away.
 *
 * @module games/menu_keys
 */

/**
 * @param {object} options
 * @param {() => boolean} options.wants - whether a press now opens the menu
 *   (a match running, its menu shut)
 * @param {() => void} options.open - open it
 * @param {boolean} [options.onHidden] - a hidden tab opens it too
 * @param {EventTarget} [options.target] - where the keys are heard
 * @param {Document} [options.doc]
 * @returns {() => void} stop listening
 */
/**
 * Whether the menu over the stage `el` sits in is on screen: then Esc is the
 * menu's own, and closes it.
 * @param {Element} el - anything on the stage
 * @returns {boolean}
 */
export function menuShown(el) {
  const menu = el.closest(".game-stage")?.querySelector('[role="dialog"]');
  return Boolean(menu && menu.offsetParent !== null);
}

export function watchMenuKeys({ wants, open, onHidden = false, target = window, doc = document }) {
  const keydown = (event) => {
    // A held key repeats: one press, one menu.
    if (event.key !== "Escape" || event.repeat || !wants()) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    open();
  };
  const visibility = () => {
    if (doc.visibilityState === "hidden" && wants()) open();
  };

  target.addEventListener("keydown", keydown, true);
  if (onHidden) doc.addEventListener("visibilitychange", visibility);

  return () => {
    target.removeEventListener("keydown", keydown, true);
    if (onHidden) doc.removeEventListener("visibilitychange", visibility);
  };
}
