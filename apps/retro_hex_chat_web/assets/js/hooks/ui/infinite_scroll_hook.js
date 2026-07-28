/**
 * Edge-triggered pagination for any scrollable list.
 *
 * Watches one edge of its own element and pushes `load_more` when the reader
 * approaches it. Everything the hook needs is server-owned and arrives as data
 * attributes, so the island stays the single authority on pagination state:
 *
 *   data-edge="top" | "bottom"   which edge to watch (default "bottom")
 *   data-threshold="400"         px before the edge that count as "near"
 *   data-target                  phx-target of the owning island (optional)
 *   data-event                   event to push (default "load_more")
 *   data-has-more="true|false"   server says whether another page exists
 *   data-loading="true|false"    server says a page is already in flight
 *
 * `data-event` exists because an island often owns several paginated lists and
 * they all share one phx-target, so the event name is the only thing that can
 * tell the server which list reached its edge.
 *
 * Two behaviours here are not incidental and must survive any rewrite:
 *
 * 1. **A real user gesture is required.** Programmatic scrolling — pinning to
 *    the bottom, restoring a position, a test setting `scrollTop` — must never
 *    paginate. Without this the auto-scroll of a chat viewport would page the
 *    whole history on its own.
 *
 * 2. **Overrun is reported, not swallowed.** When the reader grabs the scrollbar
 *    and lands on the edge in one move they did not read their way there, so
 *    `{_overran: true}` goes with the event and the server may reset to the
 *    first page instead of appending. Semantics borrowed from LiveView's own
 *    `phx-viewport-*` bindings.
 *
 * Why not `phx-viewport-top`/`phx-viewport-bottom`: those need the container
 * padded to roughly twice the viewport height, which is meaningless for lists
 * living inside fixed-height desktop windows, and they have open bugs where a
 * hidden last child silences the trigger (phoenix_live_view issue 3639) — a
 * layout this app uses in several places.
 */

import {
  createScrollIntent,
  didOverrun,
  isNearEdge,
  parseThreshold,
} from "../../lib/ui/infinite_scroll.js";

const InfiniteScrollHook = {
  mounted() {
    this.pending = false;
    this.intent = createScrollIntent();
    this.lastScrollTop = this.el.scrollTop;
    this.prevScrollHeight = null;

    this._onScroll = () => this.handleScroll();
    this._onGesture = () => this.intent.mark();
    this._onKeyDown = (event) => this.intent.markFromKey(event.key);

    this.el.addEventListener("scroll", this._onScroll, { passive: true });
    this.el.addEventListener("wheel", this._onGesture, { passive: true });
    this.el.addEventListener("touchstart", this._onGesture, { passive: true });
    this.el.addEventListener("touchmove", this._onGesture, { passive: true });
    this.el.addEventListener("pointerdown", this._onGesture);
    this.el.addEventListener("keydown", this._onKeyDown);
  },

  // Captured before LiveView patches the list so `updated()` can tell how much
  // taller it got. Only meaningful for a top-edge list, where new rows land
  // above the reader and would otherwise shove their content out of view.
  beforeUpdate() {
    this.prevScrollHeight = this.el.scrollHeight;
  },

  updated() {
    this.restoreScrollAfterPrepend();
    // The patch IS the server's answer: whatever it decided about has_more and
    // loading is now in the data attributes, so the hook may ask again.
    this.pending = false;
  },

  destroyed() {
    this.intent.clear();
    this.el.removeEventListener("scroll", this._onScroll);
    this.el.removeEventListener("wheel", this._onGesture);
    this.el.removeEventListener("touchstart", this._onGesture);
    this.el.removeEventListener("touchmove", this._onGesture);
    this.el.removeEventListener("pointerdown", this._onGesture);
    this.el.removeEventListener("keydown", this._onKeyDown);
  },

  // ── Configuration (server-owned, read fresh every time) ──────────

  edge() {
    return this.el.dataset.edge === "top" ? "top" : "bottom";
  },

  threshold() {
    return parseThreshold(this.el.dataset.threshold);
  },

  hasMore() {
    return this.el.dataset.hasMore !== "false";
  },

  loading() {
    return this.el.dataset.loading === "true";
  },

  eventName() {
    return this.el.dataset.event || "load_more";
  },

  // ── Scroll handling ──────────────────────────────────────────────

  handleScroll() {
    const previousTop = this.lastScrollTop;
    const currentTop = this.el.scrollTop;
    this.lastScrollTop = currentTop;

    if (!this.intent.active || this.pending || this.loading() || !this.hasMore()) return;
    if (!isNearEdge(this.el, this.edge(), this.threshold())) return;

    this.pending = true;
    const overran = didOverrun(this.el, this.edge(), previousTop, currentTop);
    this.push(overran ? { _overran: true } : {});
  },

  push(payload) {
    const target = this.el.dataset.target;
    const event = this.eventName();

    if (target) {
      this.pushEventTo(target, event, payload);
    } else {
      this.pushEvent(event, payload);
    }
  },

  // ── Reading position ─────────────────────────────────────────────

  restoreScrollAfterPrepend() {
    if (this.edge() !== "top" || this.prevScrollHeight === null) return;

    const grew = this.el.scrollHeight - this.prevScrollHeight;
    this.prevScrollHeight = null;

    if (grew > 0) this.el.scrollTop += grew;
  },
};

export default InfiniteScrollHook;
