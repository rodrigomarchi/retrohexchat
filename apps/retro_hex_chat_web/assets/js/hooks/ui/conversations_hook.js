/**
 * LiveView hook for the conversations sidebar: the row menu button, the
 * right-click and long-press that open the same menu, feedback toasts, and the
 * channel join flash.
 *
 * The button is the only one of the three a person can find without being told,
 * so it is the one the other two are accelerators for. All three end in the
 * same `channel_right_click` / `pm_right_click` push; the button supplies the
 * menu's coordinates from its own rect so the menu opens on the row it belongs
 * to rather than wherever a pointer last was.
 */
import { findClosestWithData } from "../../lib/ui/dom.js";
import { showFeedbackToast } from "../../lib/notifications/feedback_toast.js";
import { createLongPress } from "../../lib/input/long_press.js";

const ConversationsHook = {
  mounted() {
    this.suppressContextClick = false;
    this.longPress = createLongPress({ onFire: (context) => this.fireLongPress(context) });

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
        if (this.longPress.consumeClickSuppression()) {
          e.preventDefault();
          e.stopPropagation();
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

    this.el.addEventListener(
      "click",
      (e) => {
        const trigger = e.target.closest("[data-conversations-menu]");
        if (!trigger) return;

        e.preventDefault();
        e.stopPropagation();
        this.openRowMenu(trigger);
      },
      true,
    );

    this._pointerDown = (e) => this.startLongPress(e);
    this._pointerMove = (e) => this.moveLongPress(e);
    this._pointerUp = (e) => this.finishLongPress(e);
    this._pointerCancel = () => this.longPress.cancel();

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
    this.longPress.cancel();
    clearTimeout(this._suppressContextClickTimer);
    this.el.removeEventListener("pointerdown", this._pointerDown);
    this.el.removeEventListener("pointermove", this._pointerMove);
    this.el.removeEventListener("pointerup", this._pointerUp);
    this.el.removeEventListener("pointercancel", this._pointerCancel);
  },

  openRowMenu(trigger) {
    const rect = trigger.getBoundingClientRect();
    const x = Math.round(rect.left);
    const y = Math.round(rect.bottom);

    const channel = findClosestWithData(trigger, "[data-channel]", "channel");
    if (channel) {
      this.pushEvent("channel_right_click", { channel, x, y });
      return;
    }

    const nick = findClosestWithData(trigger, "[data-nick]", "nick");
    if (nick) {
      this.pushEvent("pm_right_click", { nick, x, y });
    }
  },

  startLongPress(e) {
    if (e.pointerType !== "touch" || e.button !== 0) return;

    const channel = findClosestWithData(e.target, "[data-channel]", "channel");
    const nick = findClosestWithData(e.target, "[data-nick]", "nick");
    if (!channel && !nick) return;

    this.longPress.start(e.clientX, e.clientY, { channel, nick, x: e.clientX, y: e.clientY });
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

  fireLongPress({ channel, nick, x, y }) {
    this.suppressContextClick = true;
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
};

export default ConversationsHook;
