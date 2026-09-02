/**
 * The chat message list's scroll and pinning — a controller, no LiveView.
 *
 * "Pinned" (the reader is at the newest message) is read from a sentinel via an
 * IntersectionObserver, not a scroll offset: no threshold to tune, and no scroll
 * listener that has to tell the reader's gestures from our own writes. Content
 * that grows after it lands — an image, a link preview, a rewrap — is caught by
 * a MutationObserver and a ResizeObserver, both of which `settle()`.
 *
 * The one place the scroll position is written in response to content is
 * `settle()`: restore the distance-from-bottom after a prepend, else stay pinned.
 * The observers are injectable so the behaviour can be driven in a test.
 *
 * @module chat/viewport_scroll
 */

// How long the rows that just arrived are allowed to keep growing before the
// hold is let go. Long enough for an image to decode, short enough that it is
// over before a reader does anything with the page.
const PREPEND_SETTLE_MS = 1500;

export function createViewportScroller(scroller, deps = {}) {
  const stream = deps.stream || null;
  const anchor = deps.anchor || null;
  const IO = deps.IntersectionObserver || globalThis.IntersectionObserver;
  const MO = deps.MutationObserver || globalThis.MutationObserver;
  const RO = deps.ResizeObserver || globalThis.ResizeObserver;
  const now = deps.now || (() => Date.now());

  let pinned = true;
  let pendingPrepend = null;
  let settlingPrepend = null;
  let settlingUntil = 0;
  let pinnedObserver = null;
  let contentObserver = null;
  let sizeObserver = null;

  const scrollToBottom = () => {
    scroller.scrollTop = scroller.scrollHeight;
  };

  const distanceFromBottom = () => scroller.scrollHeight - scroller.scrollTop;

  // The single place the scroll position is written in response to content.
  //
  // A mutation is new content and gets the restore once: that is what tells a
  // page of history apart from the next thing that lands, and treating a later
  // batch as more of the same prepend would drag the reader down every time
  // somebody spoke.
  //
  // A resize is not new content — it is the rows that just arrived finishing
  // their layout: an image decodes, a preview lands, a long line rewraps. Those
  // land after the restore and used to shove the reader down with them,
  // measured at 344px on a page of seeded history. So the target survives the
  // restore for a moment, and only the resize path may re-apply it.
  const settle = () => {
    if (pendingPrepend !== null) {
      scroller.scrollTop = scroller.scrollHeight - pendingPrepend;
      settlingPrepend = pendingPrepend;
      settlingUntil = now() + PREPEND_SETTLE_MS;
      pendingPrepend = null;
      return;
    }
    if (pinned) scrollToBottom();
  };

  // The prepended rows growing into their final height. Never a new message:
  // those arrive as mutations.
  const resettle = () => {
    if (settlingPrepend !== null && now() < settlingUntil) {
      scroller.scrollTop = scroller.scrollHeight - settlingPrepend;
      return;
    }

    settlingPrepend = null;
    if (pinned) scrollToBottom();
  };

  const releasePrepend = () => {
    pendingPrepend = null;
    settlingPrepend = null;
  };

  const controller = {
    mount() {
      scrollToBottom();

      if (typeof IO === "function" && anchor) {
        pinnedObserver = new IO(
          (entries) =>
            entries.forEach((entry) => {
              pinned = entry.isIntersecting;
              if (pinned) releasePrepend();
            }),
          { root: scroller, threshold: 0 },
        );
        pinnedObserver.observe(anchor);
      }

      const target = stream || scroller;
      if (typeof MO === "function") {
        contentObserver = new MO(() => settle());
        contentObserver.observe(target, { childList: true });
      }
      if (typeof RO === "function") {
        sizeObserver = new RO(() => resettle());
        sizeObserver.observe(target);
      }
    },

    settle,
    scrollToBottom,
    distanceFromBottom,

    /** prepend_start: hold the distance from the bottom across the prepend. */
    prepareForPrepend() {
      pendingPrepend = distanceFromBottom();
      settlingPrepend = null;
    },

    /** chat_scroll_reset: a rebuilt list looks like a prepend to an observer. */
    reset() {
      releasePrepend();
      pinned = true;
      scrollToBottom();
    },

    /** scroll_to_bottom: the server asked to jump to the newest message. */
    pinToBottom() {
      pinned = true;
      scrollToBottom();
    },

    /** clear_chat_messages: empty the stream and pin. */
    clearMessages() {
      if (stream) stream.replaceChildren();
      releasePrepend();
      pinned = true;
    },

    destroy() {
      pinnedObserver?.disconnect();
      contentObserver?.disconnect();
      sizeObserver?.disconnect();
      pinnedObserver = contentObserver = sizeObserver = null;
    },

    // Exposed for assertions.
    get pinned() {
      return pinned;
    },
    get pendingPrepend() {
      return pendingPrepend;
    },
  };

  return controller;
}
