import { describeTarget, gatedAnchor, modifiedClick } from "../../lib/chat/open_tab_targets.js";

/**
 * OpenTabConfirm — the click that asks before a second tab appears.
 *
 * Every door in the chat that opens a tab is a real anchor, and it stays one:
 * that is what keeps middle-click, "open in new tab" and the browser's own
 * status bar working, and it is what makes the failure mode the right one — with
 * no JavaScript the anchor simply opens, so this is an affordance and never a
 * control. What the hook adds is the first click: it is held, the server is
 * told where it was going, and the dialog's own button — another real anchor —
 * is what finally opens the tab.
 *
 * The listener is on `document`, not on `this.el`. A delegated listener is the
 * only way to reach a link inside message content, which is raw HTML from the
 * server rather than a component. `this.el` is the dialog's mount element,
 * chosen because it is small and stable: `pushEvent` stamps
 * `data-phx-ref-lock` on the hook's own element and later patches land in a
 * detached clone, so a hook that pushes must never sit on the shell or on a
 * scroll container.
 *
 * Capture phase, so the decision is made before anything downstream reacts to a
 * click it is not going to get.
 */
const OpenTabConfirmHook = {
  mounted() {
    this._onClick = (event) => this._handleClick(event);
    document.addEventListener("click", this._onClick, true);
  },

  destroyed() {
    document.removeEventListener("click", this._onClick, true);
  },

  _handleClick(event) {
    if (event.defaultPrevented || modifiedClick(event)) return;

    const anchor = gatedAnchor(event.target);
    if (!anchor) return;

    const target = describeTarget(anchor, window.location.origin);
    if (!target) return;

    event.preventDefault();
    event.stopPropagation();
    this.pushEvent("confirm_open_tab", target);
  },
};

export default OpenTabConfirmHook;
