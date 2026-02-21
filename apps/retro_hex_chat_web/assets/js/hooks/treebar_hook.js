/**
 * LiveView hook for treebar channel right-click context menu,
 * feedback toasts (server → client), and channel join flash.
 */
import { findClosestWithData } from "../lib/dom.js";
import { showFeedbackToast } from "../lib/feedback_toast.js";

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

    // Feedback toast from server (e.g., "Settings saved")
    this.handleEvent("feedback_toast", ({ message, duration }) => {
      showFeedbackToast(this.el, message, duration);
    });

    // Channel join flash animation
    this.handleEvent("channel_joined_flash", ({ channel }) => {
      const li = this.el.querySelector(`[data-channel="${channel}"]`);
      if (li) {
        li.classList.add("tree-join-flash");
        setTimeout(() => li.classList.remove("tree-join-flash"), 1000);
      }
    });
  },
};

export default TreebarHook;
