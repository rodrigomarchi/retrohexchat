/**
 * Asks the server for the previous page of chat history.
 *
 * Sits on a sentinel at the top of the scrollback and watches it with an
 * IntersectionObserver, which is the only thing in the scrolling element
 * allowed to push to the server: `pushEvent` stamps `data-phx-ref-lock` on the
 * element it is pushed from, and every patch arriving while that ref is in
 * flight is applied to a detached clone of that element. On the scroller itself
 * that costs the reader their scroll position; on a sentinel with no content it
 * costs nothing.
 *
 * The observer replaces a scroll listener with a distance threshold, so there
 * is no scroll bookkeeping to keep honest and no way for a programmatic scroll
 * to be mistaken for a reader arriving at the top.
 */

// A screenful of lead time: paging back reads as continuous rather than as a
// stop-and-wait at each page boundary.
const LOOKAHEAD_PX = 400;

const ChatPaginationHook = {
  mounted() {
    this.pending = false;
    this.scroller = this.el.closest("[data-chat-scroller]") || this.el.parentElement;

    if (typeof window.IntersectionObserver !== "function") return;

    this.observer = new window.IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) this.request();
      },
      {
        root: this.scroller,
        rootMargin: `${LOOKAHEAD_PX}px 0px 0px 0px`,
        threshold: 0,
      },
    );

    this.observer.observe(this.el);
  },

  destroyed() {
    if (this.observer) this.observer.disconnect();
  },

  request() {
    if (this.pending || this.el.dataset.hasMore !== "true") return;

    this.pending = true;
    this.pushEvent("load_more", {}, () => {
      this.pending = false;
      this.rearm();
    });
  },

  // An IntersectionObserver reports transitions, not states: if the page that
  // just arrived was shorter than the lead distance the sentinel never left the
  // margin, so no new entry is delivered and the scrollback would stall one page
  // short. Re-observing redelivers the current state, which either fetches the
  // next page or falls silent.
  rearm() {
    if (!this.observer || !this.el.isConnected) return;

    this.observer.unobserve(this.el);
    this.observer.observe(this.el);
  },
};

export default ChatPaginationHook;
