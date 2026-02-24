/**
 * LiveView hook for notify list double-click → open PM query.
 * Listens for dblclick on notification rows and pushes notify_dblclick event.
 */
import { findClosestWithData } from "../../lib/ui/dom.js";

const NotifyListHook = {
  mounted() {
    this.el.addEventListener("dblclick", (e) => {
      const nickname = findClosestWithData(e.target, "tr[data-nickname]", "nickname");
      if (nickname) {
        this.pushEvent("notify_dblclick", { nickname });
      }
    });
  },
};

export default NotifyListHook;
