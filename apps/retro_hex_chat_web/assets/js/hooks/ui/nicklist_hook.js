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

    this._pointerDown = (e) => this.startLongPress(e);
    this._pointerMove = (e) => this.moveLongPress(e);
    this._pointerUp = (e) => this.finishLongPress(e);
    this._pointerCancel = () => this.longPress.cancel();

    this.el.addEventListener("pointerdown", this._pointerDown);
    this.el.addEventListener("pointermove", this._pointerMove);
    this.el.addEventListener("pointerup", this._pointerUp);
    this.el.addEventListener("pointercancel", this._pointerCancel);

    this.el.addEventListener(
      "click",
      (e) => {
        if (!this.longPress.consumeClickSuppression()) return;
        e.preventDefault();
        e.stopPropagation();
      },
      true,
    );

    this.el.addEventListener("contextmenu", (e) => {
      const nick = findClosestWithData(e.target, "[data-nick]", "nick");
      if (!nick) return;

      e.preventDefault();
      this.pushEvent("nick_right_click", {
        nick,
        x: e.clientX,
        y: e.clientY,
      });
    });

    this.el.addEventListener("dblclick", (e) => {
      const nick = findClosestWithData(e.target, "[data-nick]", "nick");
      if (!nick) return;

      this.pushEvent("nicklist_dblclick", { nick });
    });

    this.el.addEventListener(
      "mouseenter",
      (e) => {
        if (isContextMenuOpen()) return;

        const nickEl = e.target.closest("[data-nick]");
        if (!nickEl || !this.el.contains(nickEl)) return;

        const nick = nickEl.dataset.nick;
        if (!nick) return;

        const rect = nickEl.getBoundingClientRect();
        startNickHoverTimer(nick, () => {
          this.pushEvent("nick_hover", {
            nick,
            x: rect.left,
            y: rect.bottom + 4,
          });
        });
      },
      true,
    );

    this.el.addEventListener("mousemove", (e) => {
      const nickEl = e.target.closest("[data-nick]");
      if (!nickEl || !this.el.contains(nickEl)) return;

      const rect = nickEl.getBoundingClientRect();
      resetNickHoverTimer(() => {
        this.pushEvent("nick_hover", {
          nick: nickEl.dataset.nick,
          x: rect.left,
          y: rect.bottom + 4,
        });
      });
    });

    this.el.addEventListener(
      "mouseleave",
      (e) => {
        const nickEl = e.target.closest("[data-nick]");
        if (!nickEl || !this.el.contains(nickEl)) return;

        cancelNickHoverTimer();
        this.pushEvent("nick_hover_dismiss", {});
      },
      true,
    );
  },

  destroyed() {
    this.longPress.cancel();
    this.el.removeEventListener("pointerdown", this._pointerDown);
    this.el.removeEventListener("pointermove", this._pointerMove);
    this.el.removeEventListener("pointerup", this._pointerUp);
    this.el.removeEventListener("pointercancel", this._pointerCancel);
  },

  startLongPress(e) {
    if (e.pointerType !== "touch" || e.button !== 0) return;

    const nick = findClosestWithData(e.target, "[data-nick]", "nick");
    if (!nick) return;

    cancelNickHoverTimer();
    this.longPress.start(e.clientX, e.clientY, { nick, x: e.clientX, y: e.clientY });
  },

  moveLongPress(e) {
    this.longPress.move(e.clientX, e.clientY);
  },

  finishLongPress(e) {
    if (this.longPress.finish()) {
      e.preventDefault();
      e.stopPropagation();
    }
  },
};

export default NicklistHook;
