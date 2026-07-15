/**
 * Pointer wiring for the on-screen virtual pad (D-pad + attack button).
 *
 * Pointer Events unify mouse, touch and pen in one handler set. The pad root
 * captures the pointer on press so a finger can slide between D-pad directions
 * without lifting (hit-tested per move, like a physical pad); sliding off the
 * pad releases movement, and `pointercancel`/detach clear everything so no
 * direction sticks. All presses feed the shared `InputController`, so a held
 * pad button walks at the same paced cadence as a held key.
 *
 * The pressed visual is the `data-pressed` attribute on the active button
 * (styled by the component's Tailwind `data-[pressed]:` variants).
 * @module space/virtual_pad
 */

export class VirtualPadController {
  /**
   * @param {object} opts
   * @param {HTMLElement} opts.root the `[data-space-pad]` element
   * @param {object} opts.input the shared `InputController`
   * @param {Function} [opts.hitTest] injected control resolver (tests):
   *   (root, x, y) -> {el, dir, action} | null
   */
  constructor({ root, input, hitTest } = {}) {
    this._root = root;
    this._input = input;
    this._hitTest = hitTest ?? defaultHitTest;
    // pointerId -> {kind: "action"|"dir", dir: string|null, el: Element|null}.
    // A "dir" pointer with dir null is a slide that is currently off every
    // control (still tracked so sliding back re-presses).
    this._pointers = new Map();
    this._onPointerDown = this._onPointerDown.bind(this);
    this._onPointerMove = this._onPointerMove.bind(this);
    this._onPointerEnd = this._onPointerEnd.bind(this);
    this._onContextMenu = (event) => event.preventDefault();
  }

  attach() {
    if (!this._root) return;
    this._root.addEventListener("pointerdown", this._onPointerDown);
    this._root.addEventListener("pointermove", this._onPointerMove);
    this._root.addEventListener("pointerup", this._onPointerEnd);
    this._root.addEventListener("pointercancel", this._onPointerEnd);
    // A long-press on mobile must not open the browser context menu.
    this._root.addEventListener("contextmenu", this._onContextMenu);
  }

  detach() {
    if (!this._root) return;
    this._root.removeEventListener("pointerdown", this._onPointerDown);
    this._root.removeEventListener("pointermove", this._onPointerMove);
    this._root.removeEventListener("pointerup", this._onPointerEnd);
    this._root.removeEventListener("pointercancel", this._onPointerEnd);
    this._root.removeEventListener("contextmenu", this._onContextMenu);
    for (const pointerId of [...this._pointers.keys()]) this._releasePointer(pointerId);
  }

  _onPointerDown(event) {
    const control = this._hitTest(this._root, event.clientX, event.clientY);
    if (!control) return;

    event.preventDefault();
    // Capture so the slide keeps reporting to the pad even outside its box.
    this._root.setPointerCapture?.(event.pointerId);

    if (control.action) {
      // Actions are one-shot on a fresh press; no slide-into, no repeat.
      this._input?.triggerAction?.(control.action);
      this._pointers.set(event.pointerId, { kind: "action", dir: null, el: control.el });
      this._setPressed(control.el, true);
      return;
    }

    this._pointers.set(event.pointerId, { kind: "dir", dir: null, el: null });
    this._slideTo(event.pointerId, control);
  }

  _onPointerMove(event) {
    const tracked = this._pointers.get(event.pointerId);
    // Only direction presses slide; an action press stays on its button.
    if (!tracked || tracked.kind !== "dir") return;

    const control = this._hitTest(this._root, event.clientX, event.clientY);
    this._slideTo(event.pointerId, control?.dir ? control : null);
  }

  _onPointerEnd(event) {
    this._releasePointer(event.pointerId);
  }

  // Move a tracked pointer onto a direction control (or off every control).
  _slideTo(pointerId, control) {
    const tracked = this._pointers.get(pointerId);
    if (!tracked) return;

    const nextDir = control?.dir ?? null;
    if (tracked.dir === nextDir) return;

    if (tracked.dir) {
      this._input?.releaseDirection?.(tracked.dir);
      this._setPressed(tracked.el, false);
    }
    if (nextDir) {
      this._input?.pressDirection?.(nextDir);
      this._setPressed(control.el, true);
    }
    this._pointers.set(pointerId, { kind: "dir", dir: nextDir, el: nextDir ? control.el : null });
  }

  _releasePointer(pointerId) {
    const tracked = this._pointers.get(pointerId);
    if (!tracked) return;
    if (tracked.dir) this._input?.releaseDirection?.(tracked.dir);
    this._setPressed(tracked.el, false);
    this._pointers.delete(pointerId);
  }

  _setPressed(el, pressed) {
    if (!el) return;
    if (pressed) el.setAttribute("data-pressed", "");
    else el.removeAttribute("data-pressed");
  }
}

// Resolve the pad control under a viewport point. Geometric (elementFromPoint),
// so it keeps working while the pad root holds the pointer capture.
function defaultHitTest(root, x, y) {
  const el = document
    .elementFromPoint(x, y)
    ?.closest("[data-space-pad-dir], [data-space-pad-action]");
  if (!el || !root.contains(el)) return null;
  return {
    el,
    dir: el.dataset.spacePadDir ?? null,
    action: el.dataset.spacePadAction ?? null,
  };
}
