/**
 * LiveView binding for the desktop window manager.
 *
 * All behaviour lives in `lib/window_manager/window_manager.js`, which knows
 * nothing about LiveView — see that module for the `data-window-*` contract and
 * the state model. This file supplies the two things only LiveView can: the
 * `pushEvent` channel that server-managed windows round-trip through, and the
 * `window_command` listener the server drives windows with
 * (`push_event("window_command", %{action: ..., id: ...})`, where action is one
 * of open | focus | flash | close | minimize | maximize | dock_pair).
 *
 * Mounted on a `.desktop` container (see the `Desktop` component family).
 */
import { createWindowManager } from "../../lib/window_manager/window_manager";

const WindowManagerHook = {
  mounted() {
    this.wm = createWindowManager(this.el, {
      pushEvent: (event, payload) => this.pushEvent(event, payload),
    });
    this.wm.mount();

    this.handleEvent("window_command", (payload = {}) =>
      this.wm.command(payload.action, payload.id, null, payload),
    );
  },

  updated() {
    this.wm.reconcile();
  },

  destroyed() {
    this.wm.destroy();
  },
};

export default WindowManagerHook;
