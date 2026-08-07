/**
 * The public pages' single window manager instance.
 *
 * These pages mount a manager immediately, then may later boot a LiveSocket for
 * the connect window — at which point `PublicWindowManagerHook` needs a manager
 * too, to reconcile the layout after every server patch. Both go through here so
 * there is exactly one: two managers on the same element would double every
 * listener, and destroying the first to remount a second re-runs the cascade and
 * reshuffles the stacking order under the reader.
 *
 * The entry bundle and the lazily imported hook chunk share this module, so they
 * share the instance it holds.
 */
import { createWindowManager } from "./window_manager";

let current = null;

/** Mount the manager for `el`, or return the one already mounted on it. */
export function mountPublicWindowManager(el) {
  if (!el) return null;
  if (current && current.el === el) return current;

  current = createWindowManager(el);
  current.mount();
  return current;
}

/** Adopt the mounted manager for `el`, mounting one only if none exists yet. */
export function adoptPublicWindowManager(el) {
  return mountPublicWindowManager(el);
}
