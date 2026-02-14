/**
 * LiveView hook for nicklist double-click → open PM query.
 * Listens for dblclick on nick <li> elements and pushes nicklist_dblclick event.
 */
import { findClosestWithData } from "../lib/dom.js";

const NicklistHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      const nick = findClosestWithData(e.target, "li[phx-value-nick]", "phx-value-nick");
      if (nick) {
        this.pushEvent("nicklist_dblclick", { nick });
      }
    });
  },
};

export default NicklistHook;
