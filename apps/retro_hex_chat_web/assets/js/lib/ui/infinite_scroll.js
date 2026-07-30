/**
 * Edge detection for paginated lists.
 *
 * Pure functions plus a small intent tracker behind `InfiniteScrollHook`, which
 * pages every ordinary list in the app. The chat scrollback does not use these:
 * its trigger is an IntersectionObserver on a sentinel, because the element that
 * asks for a page must not be the element that scrolls.
 */

export const DEFAULT_THRESHOLD_PX = 400;
export const SCROLL_INTENT_MS = 1_000;

export const SCROLL_INTENT_KEYS = new Set([
  "ArrowUp",
  "ArrowDown",
  "PageUp",
  "PageDown",
  "Home",
  "End",
  " ",
]);

/** Whether the reader is within `threshold` px of the watched edge. */
export function isNearEdge(el, edge, threshold = DEFAULT_THRESHOLD_PX) {
  if (edge === "top") return el.scrollTop <= threshold;

  const distanceToBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
  return distanceToBottom <= threshold;
}

/**
 * Whether the reader arrived at the edge by throwing the scrollbar rather than
 * reading their way there: more than a viewport of movement in a single scroll
 * event, landing on the edge.
 *
 * The server may want to reset to the first page instead of appending — the
 * same distinction LiveView's own viewport bindings report as `_overran`.
 */
export function didOverrun(el, edge, previousTop, currentTop) {
  const jumped = Math.abs(currentTop - previousTop) > el.clientHeight;
  if (!jumped) return false;

  if (edge === "top") return currentTop === 0;

  return currentTop >= el.scrollHeight - el.clientHeight;
}

/**
 * Tracks whether a real user gesture happened recently.
 *
 * Pagination must never be triggered by a programmatic scroll — the chat pins
 * itself to the bottom by writing `scrollTop`, and without this gate that pin
 * would page through the entire history on its own.
 */
export function createScrollIntent(windowMs = SCROLL_INTENT_MS) {
  let active = false;
  let timer = null;

  return {
    get active() {
      return active;
    },
    mark() {
      active = true;
      if (timer) clearTimeout(timer);
      timer = setTimeout(() => {
        active = false;
        timer = null;
      }, windowMs);
    },
    markFromKey(key) {
      if (SCROLL_INTENT_KEYS.has(key)) this.mark();
    },
    clear() {
      if (timer) clearTimeout(timer);
      timer = null;
      active = false;
    },
  };
}

/** Parses a `data-threshold` attribute, falling back to the default. */
export function parseThreshold(raw) {
  const value = Number.parseInt(raw, 10);
  return Number.isFinite(value) && value >= 0 ? value : DEFAULT_THRESHOLD_PX;
}
