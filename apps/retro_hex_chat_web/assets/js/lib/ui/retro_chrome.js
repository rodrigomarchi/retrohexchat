/**
 * The Win98 behaviour the chrome needs beyond CSS: tooltips over every
 * `title`, and the arrows of every up-down field.
 */

import { installRetroTooltips } from "./tooltip";
import { installUpDown } from "./updown";

/**
 * @param {Document} doc
 * @returns {() => void} removes both
 */
export function installRetroChrome(doc = document) {
  const removeTooltips = installRetroTooltips(doc);
  const removeUpDown = installUpDown(doc, doc.defaultView);
  return () => {
    removeTooltips();
    removeUpDown();
  };
}
