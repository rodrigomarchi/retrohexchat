import ConnectFormHook from "./connection/connect_form_hook";
import PublicWindowManagerHook from "./ui/public_window_manager_hook";

// Hooks for the LiveSocket the public pages boot on demand, for the connect
// window and the desktop it sits in.
//
// The app's WindowManagerHook is deliberately not here. It supplies a pushEvent,
// and that seam makes `actsLocally(id)` true for every window id — the landing
// chrome's real <a href> links to other pages would stop navigating.
// PublicWindowManagerHook is the same manager without it, and it has to exist:
// once a socket is connected, every patch rebuilds the window roots from server
// markup that carries no geometry, so something must reconcile the layout back.
export const connectHooks = {
  ConnectFormHook: ConnectFormHook,
  PublicWindowManagerHook: PublicWindowManagerHook,
};

export function buildConnectHooks() {
  return connectHooks;
}
