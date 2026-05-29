/**
 * LiveView hook for nicklist user interactions.
 *
 * Right-click opens the nick context menu; double-click opens a PM. The hook is
 * mounted on the nicklist container and delegates to descendants with data-nick.
 */
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
  },
};

export default NicklistHook;
