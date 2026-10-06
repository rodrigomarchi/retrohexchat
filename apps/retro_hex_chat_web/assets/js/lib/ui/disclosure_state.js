/**
 * The one part of the popover behaviour every LiveSocket needs synchronously:
 * a morphdom `onBeforeElUpdated` step. The rest (`popover.js`) arrives with
 * the lazily loaded retro chrome.
 *
 * @module ui/disclosure_state
 */

/**
 * Carry what the browser owns into a patch: a disclosure's open state, and the
 * viewport position `placePanel` gave an open popover's panel (the server
 * renders neither, so a patch would otherwise drop both).
 */
export function keepDisclosureStateAcrossPatch(fromEl, toEl) {
  if (fromEl?.tagName === "DETAILS" && toEl?.tagName === "DETAILS") {
    toEl.open = fromEl.open;
  }
  if (fromEl?.hasAttribute?.("data-popover-panel") && fromEl.hasAttribute("style")) {
    toEl.setAttribute("style", fromEl.getAttribute("style"));
  }
}
