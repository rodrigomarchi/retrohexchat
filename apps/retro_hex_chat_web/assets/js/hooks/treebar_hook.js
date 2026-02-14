/**
 * LiveView hook for treebar channel right-click context menu.
 * Delegates contextmenu events to channel items and pushes coordinates.
 */
import { findClosestWithData } from "../lib/dom.js";

const TreebarHook = {
  mounted() {
    this.el.addEventListener("contextmenu", (e) => {
      const channel = findClosestWithData(e.target, "[data-channel]", "channel");
      if (channel) {
        e.preventDefault();
        this.pushEvent("channel_right_click", {
          channel,
          x: e.clientX,
          y: e.clientY,
        });
      }
    });
  },
};

export default TreebarHook;
