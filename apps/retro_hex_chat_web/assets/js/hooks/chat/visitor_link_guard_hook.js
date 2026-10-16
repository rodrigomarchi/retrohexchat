import { blockedLink, parseAllow } from "../../lib/chat/visitor_links.js";

/**
 * VisitorLinkGuard — no link leaves a visitor's chat.
 *
 * Mounted only for somebody reading without an account. Every link they try to
 * follow that is not open to them (`lib/chat/visitor_links.js` decides) is held,
 * and the server is told which feature it led to; it answers with the sign-in
 * window naming that feature.
 *
 * On `window`, in the capture phase: that runs before the open-tab dialog's
 * listener on `document` and before LiveView's own handling of `navigate`
 * links, so nothing downstream acts on a click a visitor may not make. Every way
 * a link is followed is covered — a click with or without modifiers, the middle
 * click (`auxclick`), the context menu with its "open in new tab", and dragging
 * the link out.
 *
 * `this.el` is a small hidden element of its own, never the shell: `pushEvent`
 * stamps a ref lock on the hook's element.
 */
const FOLLOWING = ["click", "auxclick", "contextmenu", "dragstart"];

const VisitorLinkGuardHook = {
  mounted() {
    this._allow = parseAllow(this.el.dataset.allow);
    this._onFollow = (event) => this._hold(event);
    FOLLOWING.forEach((type) => window.addEventListener(type, this._onFollow, true));
  },

  destroyed() {
    FOLLOWING.forEach((type) => window.removeEventListener(type, this._onFollow, true));
  },

  _hold(event) {
    const blocked = blockedLink(event.target, window.location.origin, this._allow);
    if (!blocked) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    // Dragging is refused without a word; it is not a thing the reader meant to open.
    if (event.type !== "dragstart") this.pushEvent("visitor_link", blocked);
  },
};

export default VisitorLinkGuardHook;
