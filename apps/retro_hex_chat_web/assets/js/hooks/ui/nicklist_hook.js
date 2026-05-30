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

const NicklistHook = {
  mounted() {
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
};

export default NicklistHook;
