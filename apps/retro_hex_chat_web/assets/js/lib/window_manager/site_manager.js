/**
 * The desktop's single window manager instance.
 *
 * The first-paint bundle (`desktop.js`) mounts a manager the moment the page
 * parses, so the window in front is placed and usable before the chat's
 * LiveSocket exists. When that socket arrives, `WindowManagerHook` adopts this
 * same instance and hands it the socket's `pushEvent` — two managers on one
 * element would double every listener, and destroying the first to mount a
 * second re-runs the cascade and reshuffles the stacking under the reader.
 *
 * The entry bundle and the lazily imported LiveSocket chunk share this module,
 * so they share the instance it holds.
 */
import { createWindowManager } from "./window_manager";

let current = null;

/** Mount the manager for `el`, or return the one already mounted on it. */
export function mountSiteWindowManager(el) {
  if (!el) return null;
  if (current && current.el === el) return current;

  current = createWindowManager(el);
  current.mount();
  return current;
}

/** The manager already mounted on `el`, or null. */
export function siteWindowManagerFor(el) {
  return current && current.el === el ? current : null;
}
