/**
 * LiveView hook for conversations sidebar channel right-click context menu,
 * nick double-click → PM, feedback toasts, and channel join flash.
 */
import { findClosestWithData } from "../lib/dom.js";
import { showFeedbackToast } from "../lib/feedback_toast.js";

const ConversationsHook = {
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

    // Double-click on nick in user list → open PM
    this.el.addEventListener("dblclick", (e) => {
      const nick = findClosestWithData(e.target, "li[data-nick]", "nick");
      if (nick) {
        this.pushEvent("nicklist_dblclick", { nick });
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
        li.classList.add("conversations-join-flash");
        setTimeout(() => li.classList.remove("conversations-join-flash"), 1000);
      }
    });
  },
};

export default ConversationsHook;
