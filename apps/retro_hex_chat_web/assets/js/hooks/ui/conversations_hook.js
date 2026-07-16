/**
 * LiveView hook for conversations sidebar channel right-click context menu,
 * nick double-click → PM, feedback toasts, and channel join flash.
 */
import { findClosestWithData } from "../../lib/ui/dom.js";
import { showFeedbackToast } from "../../lib/notifications/feedback_toast.js";

const LONG_PRESS_MS = 550;
const MOVE_TOLERANCE_PX = 10;

const ConversationsHook = {
  mounted() {
    this.suppressContextClick = false;
    this.longPress = null;
    this.suppressNextClick = false;

    this.el.addEventListener(
      "mousedown",
      (e) => {
        if (e.button !== 2) return;

        const channel = findClosestWithData(e.target, "[data-channel]", "channel");
        const nick = findClosestWithData(e.target, "[data-nick]", "nick");
        if (channel || nick) {
          this.suppressContextClick = true;
          clearTimeout(this._suppressContextClickTimer);
          this._suppressContextClickTimer = setTimeout(() => {
            this.suppressContextClick = false;
          }, 500);
          e.stopPropagation();
        }
      },
      true,
    );

    this.el.addEventListener(
      "click",
      (e) => {
        if (this.suppressNextClick) {
          e.preventDefault();
          e.stopPropagation();
          this.suppressNextClick = false;
          return;
        }

        if (!this.suppressContextClick) return;

        const channel = findClosestWithData(e.target, "[data-channel]", "channel");
        const nick = findClosestWithData(e.target, "[data-nick]", "nick");
        if (channel || nick) {
          e.preventDefault();
          e.stopPropagation();
          this.suppressContextClick = false;
        }
      },
      true,
    );

    this._pointerDown = (e) => this.startLongPress(e);
    this._pointerMove = (e) => this.moveLongPress(e);
    this._pointerUp = (e) => this.finishLongPress(e);
    this._pointerCancel = () => this.cancelLongPress();

    this.el.addEventListener("pointerdown", this._pointerDown);
    this.el.addEventListener("pointermove", this._pointerMove);
    this.el.addEventListener("pointerup", this._pointerUp);
    this.el.addEventListener("pointercancel", this._pointerCancel);

    this.el.addEventListener("contextmenu", (e) => {
      const channel = findClosestWithData(e.target, "[data-channel]", "channel");
      if (channel) {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent("channel_right_click", {
          channel,
          x: e.clientX,
          y: e.clientY,
        });
        return;
      }

      const nick = findClosestWithData(e.target, "[data-nick]", "nick");
      if (nick) {
        e.preventDefault();
        e.stopPropagation();
        this.pushEvent("pm_right_click", {
          nick,
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

  destroyed() {
    this.cancelLongPress();
    clearTimeout(this._suppressContextClickTimer);
    this.el.removeEventListener("pointerdown", this._pointerDown);
    this.el.removeEventListener("pointermove", this._pointerMove);
    this.el.removeEventListener("pointerup", this._pointerUp);
    this.el.removeEventListener("pointercancel", this._pointerCancel);
  },

  startLongPress(e) {
    if (e.pointerType !== "touch" || e.button !== 0) return;

    const channel = findClosestWithData(e.target, "[data-channel]", "channel");
    const nick = findClosestWithData(e.target, "[data-nick]", "nick");
    if (!channel && !nick) return;

    this.cancelLongPress();
    this.longPress = {
      channel,
      nick,
      x: e.clientX,
      y: e.clientY,
      fired: false,
      timer: setTimeout(() => this.fireLongPress(), LONG_PRESS_MS),
    };
  },

  moveLongPress(e) {
    if (!this.longPress) return;
    if (this.longPress.fired) return;

    const dx = Math.abs(e.clientX - this.longPress.x);
    const dy = Math.abs(e.clientY - this.longPress.y);
    if (dx > MOVE_TOLERANCE_PX || dy > MOVE_TOLERANCE_PX) {
      this.cancelLongPress();
    }
  },

  finishLongPress(e) {
    if (this.longPress?.fired) {
      e.preventDefault();
      e.stopPropagation();
    }
    this.cancelLongPress({ keepClickSuppression: true });
  },

  fireLongPress() {
    if (!this.longPress) return;

    const { channel, nick, x, y } = this.longPress;
    this.longPress.fired = true;
    this.suppressContextClick = true;
    this.suppressNextClick = true;
    clearTimeout(this._suppressContextClickTimer);
    this._suppressContextClickTimer = setTimeout(() => {
      this.suppressContextClick = false;
    }, 500);

    if (channel) {
      this.pushEvent("channel_right_click", { channel, x, y });
    } else if (nick) {
      this.pushEvent("pm_right_click", { nick, x, y });
    }
  },

  cancelLongPress({ keepClickSuppression = false } = {}) {
    if (this.longPress?.timer) clearTimeout(this.longPress.timer);
    this.longPress = null;
    if (!keepClickSuppression) this.suppressNextClick = false;
  },
};

export default ConversationsHook;
