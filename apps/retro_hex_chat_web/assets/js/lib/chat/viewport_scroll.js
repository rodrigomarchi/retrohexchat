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

export function createViewportScroller(scroller, deps = {}) {
  const stream = deps.stream || null;
  const anchor = deps.anchor || null;
  const IO = deps.IntersectionObserver || globalThis.IntersectionObserver;
  const MO = deps.MutationObserver || globalThis.MutationObserver;
  const RO = deps.ResizeObserver || globalThis.ResizeObserver;

  let pinned = true;
  let pendingPrepend = null;
  let pinnedObserver = null;
  let contentObserver = null;
  let sizeObserver = null;

  const scrollToBottom = () => {
    scroller.scrollTop = scroller.scrollHeight;
  };

  const distanceFromBottom = () => scroller.scrollHeight - scroller.scrollTop;

  // The single place the scroll position is written in response to content.
  const settle = () => {
    if (pendingPrepend !== null) {
      scroller.scrollTop = scroller.scrollHeight - pendingPrepend;
      pendingPrepend = null;
      return;
    }
    if (pinned) scrollToBottom();
  };

  const controller = {
    mount() {
      scrollToBottom();

      if (typeof IO === "function" && anchor) {
        pinnedObserver = new IO(
          (entries) => entries.forEach((entry) => (pinned = entry.isIntersecting)),
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
        sizeObserver = new RO(() => settle());
        sizeObserver.observe(target);
      }
    },

    settle,
    scrollToBottom,
    distanceFromBottom,

    /** prepend_start: hold the distance from the bottom across the prepend. */
    prepareForPrepend() {
      pendingPrepend = distanceFromBottom();
    },

    /** chat_scroll_reset: a rebuilt list looks like a prepend to an observer. */
    reset() {
      pendingPrepend = null;
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
      pendingPrepend = null;
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
