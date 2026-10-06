/**
 * The Win98 behaviour the chrome needs beyond CSS: tooltips over every
 * `title`, the arrows of every up-down field, and how popovers close and
 * place themselves.
 */

import { installPopoverBehaviour } from "./popover";
import { installRetroTooltips } from "./tooltip";
import { installUpDown } from "./updown";

/**
 * @param {Document} doc
 * @returns {() => void} removes both
 */
export function installRetroChrome(doc = document) {
  installPopoverBehaviour(doc);
  const removeTooltips = installRetroTooltips(doc);
  const removeUpDown = installUpDown(doc, doc.defaultView);
  return () => {
    removeTooltips();
    removeUpDown();
  };
}
