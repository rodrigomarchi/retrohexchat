/**
 * LiveView hook for nicklist user interactions.
 *
 * Right-click opens the nick context menu; double-click opens a PM. The hook is
 * mounted on the nicklist container and delegates to descendants with data-nick.
 */
import {
  cancelNickHoverTimer,
  isContextMenuOpen,
  resetNickHoverTimer,
  startNickHoverTimer,
} from "../../lib/chat/interactive.js";
import { findClosestWithData } from "../../lib/ui/dom.js";
import { createLongPress } from "../../lib/input/long_press.js";

const NicklistHook = {
  mounted() {
    this.longPress = createLongPress({
      onFire: ({ nick, x, y }) => this.pushEvent("nick_right_click", { nick, x, y }),
    });

    // Every listener it puts on the list, so `destroyed` takes each one off.
    this._listeners = [
      ["pointerdown", (e) => this.startLongPress(e)],
      ["pointermove", (e) => this.longPress.move(e.clientX, e.clientY)],
      ["pointerup", (e) => this.longPress.finishEvent(e)],
      ["pointercancel", () => this.longPress.cancel()],
      ["click", (e) => this.suppressLongPressClick(e), true],
      ["contextmenu", (e) => this.openMenu(e)],
      ["dblclick", (e) => this.openQuery(e)],
      ["mouseenter", (e) => this.startHover(e), true],
      ["mousemove", (e) => this.resetHover(e)],
      ["mouseleave", (e) => this.endHover(e), true],
    ];
    for (const [type, fn, capture] of this._listeners) {
      this.el.addEventListener(type, fn, capture);
    }
  },

  destroyed() {
    this.longPress.cancel();
    // A hover card asked for now would land on a view that is gone.
    cancelNickHoverTimer();
    for (const [type, fn, capture] of this._listeners) {
      this.el.removeEventListener(type, fn, capture);
    }
  },

  // The click a lift synthesises after a long press opened the menu.
  suppressLongPressClick(e) {
    if (!this.longPress.consumeClickSuppression()) return;
    e.preventDefault();
    e.stopPropagation();
  },

  openMenu(e) {
    const nick = findClosestWithData(e.target, "[data-nick]", "nick");
    if (!nick) return;

    e.preventDefault();
    this.pushEvent("nick_right_click", { nick, x: e.clientX, y: e.clientY });
  },

  openQuery(e) {
    const nick = findClosestWithData(e.target, "[data-nick]", "nick");
    if (nick) this.pushEvent("nicklist_dblclick", { nick });
  },

  hoveredNick(e) {
    const nickEl = e.target.closest?.("[data-nick]");
    return nickEl && this.el.contains(nickEl) ? nickEl : null;
  },

  pushHover(nickEl) {
    const rect = nickEl.getBoundingClientRect();
    this.pushEvent("nick_hover", { nick: nickEl.dataset.nick, x: rect.left, y: rect.bottom + 4 });
  },

  startHover(e) {
    if (isContextMenuOpen()) return;
    const nickEl = this.hoveredNick(e);
    if (!nickEl?.dataset.nick) return;
    startNickHoverTimer(nickEl.dataset.nick, () => this.pushHover(nickEl));
  },

  resetHover(e) {
    const nickEl = this.hoveredNick(e);
    if (nickEl) resetNickHoverTimer(() => this.pushHover(nickEl));
  },

  endHover(e) {
    if (!this.hoveredNick(e)) return;
    cancelNickHoverTimer();
    this.pushEvent("nick_hover_dismiss", {});
  },

  startLongPress(e) {
    if (e.pointerType !== "touch" || e.button !== 0) return;

    const nick = findClosestWithData(e.target, "[data-nick]", "nick");
    if (!nick) return;

    cancelNickHoverTimer();
    this.longPress.start(e.clientX, e.clientY, { nick, x: e.clientX, y: e.clientY });
  },
};

export default NicklistHook;
