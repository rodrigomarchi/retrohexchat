/**
 * The menu bar of the page in front, before and after the chat starts.
 *
 * The first-paint bundle (`desktop.js`) mounts the page's menu bar the moment
 * the page parses, so its menus open before the chat's LiveSocket exists. When
 * that socket arrives, `MenuBarHook` adopts this same instance: a second engine
 * on the same element would answer every click twice — opening and closing the
 * menu in one tap — and the hook is what puts an open menu back after the
 * LiveView patches the bar.
 *
 * The entry bundle and the lazily imported LiveSocket chunk share this module,
 * so they share the instance it holds.
 */
import { createMenuBar } from "./menu_bar";

let current = null;

/** Mount the menu bar for `el`, or return the one already mounted on it. */
export function mountSiteMenuBar(el) {
  if (!el) return null;
  if (current && current.el === el) return current.bar;

  const bar = createMenuBar(el);
  bar.mount();
  current = { el, bar };
  return bar;
}

/** The menu bar already mounted on `el`, or null. */
export function siteMenuBarFor(el) {
  return current && current.el === el ? current.bar : null;
}
