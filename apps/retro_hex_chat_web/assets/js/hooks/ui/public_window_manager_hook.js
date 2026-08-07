/**
 * Window manager binding for the public pages.
 *
 * It adopts the manager the public bundle already mounted rather than creating
 * one: two on the same element would double every listener, and swapping them
 * re-runs the cascade and reshuffles the stacking order under the reader.
 *
 * The manager it adopts has no `pushEvent`, deliberately. That seam decides
 * `actsLocally(id)`, and with it present the manager treats every window id as
 * one it can open here — so the landing chrome's real <a href> links to other
 * pages would be swallowed instead of navigating. Nothing about a window on
 * these pages round-trips to the server.
 *
 * The hook still has to exist. Once these pages boot a LiveSocket for the
 * connect window, every server patch rebuilds the window roots from markup that
 * always carries `u-hidden` and no geometry. `reconcile()` on `updated()` is
 * what puts the client-owned layout back; without it the desktop collapses the
 * moment the socket connects.
 */
import { adoptPublicWindowManager } from "../../lib/window_manager/public_manager";

const PublicWindowManagerHook = {
  mounted() {
    this.wm = adoptPublicWindowManager(this.el);
    // Connecting is itself a patch: LiveView has already rebuilt the window
    // roots from server markup by the time this runs, and no `updated()`
    // follows. Reconciling here is what survives that first render — adopting
    // alone would leave every window hidden at 0×0.
    this.wm?.reconcile();
  },

  updated() {
    this.wm?.reconcile();
  },
};

export default PublicWindowManagerHook;
