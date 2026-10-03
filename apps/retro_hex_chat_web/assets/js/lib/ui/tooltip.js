/**
 * Win98 tooltips for every `title` attribute on the page.
 *
 * The browser's own tooltip is the operating system's: a rounded, shadowed
 * macOS or Windows 11 bubble. This draws the Windows 98 one instead — pale
 * yellow, a one-pixel black border, under the pointer — and keeps the
 * markup's `title` as the single source of the text.
 *
 * While the pointer rests on an element its `title` is taken off it — the only
 * way to stop the browser drawing its own bubble on top — and kept aside; it
 * goes back the moment the pointer leaves. A LiveView patch that puts the
 * `title` back meanwhile is taken off again on the next pointer move. Timing follows Windows: the
 * tip waits half a second, disappears after a few seconds or on any press, key
 * or scroll of what it points at, and a neighbour's tip shows almost at once while one was just up.
 */

const SHOW_DELAY_MS = 500;
const RESHOW_DELAY_MS = 100;
const RESHOW_WINDOW_MS = 500;
const AUTO_HIDE_MS = 5000;
const POINTER_OFFSET_Y = 20;
const EDGE_MARGIN = 2;

/**
 * Takes the `title` off an element so the browser does not draw its own, and
 * keeps it in `stash`. A `title` already taken stays where it is.
 *
 * @param {Element} el
 * @param {WeakMap<Element, string>} stash
 * @returns {string} the text, or "" when there is none
 */
export function stashTitle(el, stash) {
  const title = el.getAttribute("title");
  if (title === null) return stash.get(el) || "";
  stash.set(el, title);
  el.removeAttribute("title");
  return title;
}

/**
 * Puts a stashed `title` back. A `title` that arrived meanwhile (a LiveView
 * patch re-rendering the element) is newer and wins.
 *
 * @param {Element} el
 * @param {WeakMap<Element, string>} stash
 */
export function restoreTitle(el, stash) {
  if (!stash.has(el)) return;
  if (!el.hasAttribute("title")) el.setAttribute("title", stash.get(el));
  stash.delete(el);
}

/**
 * Where the tip goes: below the pointer, kept inside the viewport.
 *
 * @param {{x: number, y: number}} pointer
 * @param {{width: number, height: number}} tip
 * @param {{width: number, height: number}} viewport
 * @returns {{left: number, top: number}}
 */
export function placeTooltip(pointer, tip, viewport) {
  const left = Math.max(EDGE_MARGIN, Math.min(pointer.x, viewport.width - tip.width - EDGE_MARGIN));
  const below = pointer.y + POINTER_OFFSET_Y;
  const top =
    below + tip.height + EDGE_MARGIN > viewport.height
      ? Math.max(EDGE_MARGIN, pointer.y - tip.height - EDGE_MARGIN)
      : below;
  return { left, top };
}

/**
 * Installs the tooltips on a document.
 *
 * @param {Document} doc
 * @param {{setTimeout?: Function, clearTimeout?: Function, now?: () => number}} [clock]
 * @returns {() => void} removes the listeners and the tip element
 */
export function installRetroTooltips(doc = document, clock = {}) {
  const view = doc.defaultView;
  const setTimer = clock.setTimeout || view.setTimeout.bind(view);
  const clearTimer = clock.clearTimeout || view.clearTimeout.bind(view);
  const now = clock.now || (() => Date.now());

  const tip = doc.createElement("div");
  tip.className = "rhc-tooltip";
  tip.setAttribute("role", "tooltip");
  tip.hidden = true;
  doc.body.appendChild(tip);

  const stash = new WeakMap();
  const state = { target: null, timer: null, pointer: { x: 0, y: 0 }, hiddenAt: -Infinity };

  const clear = () => {
    if (state.timer !== null) clearTimer(state.timer);
    state.timer = null;
  };

  const hide = () => {
    clear();
    if (!tip.hidden) state.hiddenAt = now();
    tip.hidden = true;
  };

  const release = () => {
    hide();
    if (state.target) restoreTitle(state.target, stash);
    state.target = null;
  };

  const show = () => {
    const el = state.target;
    if (!el || !el.isConnected) return release();

    const text = stashTitle(el, stash);
    if (!text.trim()) return release();

    tip.textContent = text;
    tip.hidden = false;
    const box = tip.getBoundingClientRect();
    const { left, top } = placeTooltip(
      state.pointer,
      { width: box.width, height: box.height },
      { width: view.innerWidth, height: view.innerHeight },
    );
    tip.style.left = `${left}px`;
    tip.style.top = `${top}px`;
    state.timer = setTimer(hide, AUTO_HIDE_MS);
  };

  // The nearest element that carries a tip — with its `title`, or with one
  // already put aside, which no `[title]` selector matches any more.
  const titledAncestor = (node) => {
    for (let el = node; el && el.nodeType === 1; el = el.parentElement) {
      if (el.hasAttribute("title") || stash.has(el)) return el;
    }
    return null;
  };

  const onPointerOver = (event) => {
    if (event.pointerType === "touch") return;
    const el = titledAncestor(event.target);
    if (el === state.target) return;

    const wasShowing = !tip.hidden || now() - state.hiddenAt < RESHOW_WINDOW_MS;
    release();
    if (!el || !stashTitle(el, stash).trim()) return;

    state.target = el;
    state.pointer = { x: event.clientX, y: event.clientY };
    state.timer = setTimer(show, wasShowing ? RESHOW_DELAY_MS : SHOW_DELAY_MS);
  };

  const onPointerMove = (event) => {
    if (!state.target) return;
    if (state.target.hasAttribute("title")) stashTitle(state.target, stash);
    if (tip.hidden) state.pointer = { x: event.clientX, y: event.clientY };
  };

  // Only a scroll that moves the element itself ends its tip. The chat log
  // scrolls on its own all the time — new messages, restored positions — and a
  // tip over the sidebar has nothing to do with that.
  const onScroll = (event) => {
    if (!state.target) return;
    const scroller = event.target === doc ? doc.documentElement : event.target;
    if (scroller.contains?.(state.target)) hide();
  };

  const onPointerOut = (event) => {
    if (!state.target) return;
    const next = event.relatedTarget;
    if (next && state.target.contains(next)) return;
    release();
  };

  doc.addEventListener("pointerover", onPointerOver);
  doc.addEventListener("pointermove", onPointerMove, { passive: true });
  doc.addEventListener("pointerout", onPointerOut);
  doc.addEventListener("pointerdown", hide, true);
  doc.addEventListener("keydown", hide, true);
  doc.addEventListener("scroll", onScroll, { capture: true, passive: true });

  return () => {
    release();
    doc.removeEventListener("pointerover", onPointerOver);
    doc.removeEventListener("pointermove", onPointerMove);
    doc.removeEventListener("pointerout", onPointerOut);
    doc.removeEventListener("pointerdown", hide, true);
    doc.removeEventListener("keydown", hide, true);
    doc.removeEventListener("scroll", onScroll, { capture: true });
    tip.remove();
  };
}
