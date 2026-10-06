import { log } from "../logger";

/**
 * Loads the Win98 tooltips, up-down arrows and popover behaviour off the
 * app's critical path. None is needed to draw the first screen — a tooltip
 * waits half a second for a resting pointer, an arrow or a popover waits for a
 * click — so they arrive as their own chunk right after boot instead of
 * weighing on `app.js`.
 *
 * @param {Document} doc
 * @returns {Promise<void>}
 */
export function loadRetroChrome(doc = document) {
  return import("./retro_chrome")
    .then(({ installRetroChrome }) => {
      installRetroChrome(doc);
    })
    .catch((error) => {
      log.error("[retro_chrome] tooltips and up-down arrows failed to load", error);
    });
}
