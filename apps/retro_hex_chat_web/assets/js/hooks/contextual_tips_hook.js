/**
 * LiveView hook for contextual tips and progressive disclosure.
 *
 * Manages a queue of tips, shows 98.css-styled toast notifications,
 * persists seen state in localStorage, and handles idle detection.
 * All tip logic lives in lib/tips.js; DOM creation in lib/toast.js.
 */
import {
  isSuppressed,
  setSuppressed,
  shouldShowTip,
  markTipSeen,
  markPreempted,
  getTipById,
  QUEUE_GAP_MS,
  AUTO_DISMISS_MS,
  IDLE_TIMEOUT_MS,
  TIP_IDS,
} from "../lib/tips.js";
import { createToastElement, animateIn, animateOut } from "../lib/toast.js";
import { isOnboardingComplete } from "../lib/onboarding.js";

const ContextualTipsHook = {
  mounted() {
    this.queue = [];
    this.isShowing = false;
    this.cooldownTimer = null;
    this.autoDismissTimer = null;
    this.idleTimer = null;
    this.idleFired = false;
    this.dialogPollTimer = null;

    this.handleEvent("tip_trigger", ({ tip }) => {
      if (tip === "help_used") {
        markPreempted(tip);
        return;
      }
      this.enqueueTip(tip);
    });

    this.handleEvent("tips_toggle", ({ enabled }) => {
      setSuppressed(!enabled);
      this.pushEvent("tips_state_sync", { suppressed: !enabled });
      if (!enabled) {
        this.clearQueue();
      }
    });

    this.pushEvent("tips_state_sync", { suppressed: isSuppressed() });

    this.startIdleTimer();
  },

  destroyed() {
    this.clearAllTimers();
    this.removeIdleListeners();
    this.removeCurrentToast();
  },

  enqueueTip(tipId) {
    if (!isOnboardingComplete()) return;
    if (isSuppressed()) return;
    if (!shouldShowTip(tipId)) return;

    const tip = getTipById(tipId);
    if (!tip) return;

    this.queue.push(tip);
    this.processQueue();
  },

  processQueue() {
    if (this.isShowing) return;
    if (this.queue.length === 0) return;
    if (this.cooldownTimer) return;

    if (this.isDialogOpen()) {
      this.startDialogPolling();
      return;
    }

    if (this.isOnboardingBannerVisible()) {
      setTimeout(() => this.processQueue(), 5000);
      return;
    }

    const tip = this.queue.shift();

    if (!shouldShowTip(tip.id)) {
      this.processQueue();
      return;
    }

    this.showToast(tip);
  },

  showToast(tip) {
    this.isShowing = true;

    const onDismiss = (checked) => {
      if (checked) {
        setSuppressed(true);
        this.pushEvent("tips_state_sync", { suppressed: true });
        this.clearQueue();
      }
      this.dismissToast(tip.id);
    };

    const toastEl = createToastElement(tip, {
      showCheckbox: true,
      onDismiss,
    });

    this.el.appendChild(toastEl);
    this.currentToast = toastEl;

    requestAnimationFrame(() => {
      animateIn(toastEl);
    });

    this.autoDismissTimer = setTimeout(() => {
      this.dismissToast(tip.id);
    }, AUTO_DISMISS_MS);
  },

  async dismissToast(tipId) {
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer);
      this.autoDismissTimer = null;
    }

    markTipSeen(tipId);

    if (this.currentToast) {
      await animateOut(this.currentToast);
      this.currentToast.remove();
      this.currentToast = null;
    }

    this.isShowing = false;

    if (this.queue.length > 0 && !isSuppressed()) {
      this.cooldownTimer = setTimeout(() => {
        this.cooldownTimer = null;
        this.processQueue();
      }, QUEUE_GAP_MS);
    }
  },

  clearQueue() {
    this.queue = [];
    if (this.cooldownTimer) {
      clearTimeout(this.cooldownTimer);
      this.cooldownTimer = null;
    }
  },

  removeCurrentToast() {
    if (this.currentToast) {
      this.currentToast.remove();
      this.currentToast = null;
    }
  },

  isDialogOpen() {
    return !!document.querySelector(".dialog-overlay");
  },

  isOnboardingBannerVisible() {
    return !!document.querySelector(".onboarding-tip-banner");
  },

  startDialogPolling() {
    if (this.dialogPollTimer) return;
    this.dialogPollTimer = setInterval(() => {
      if (!this.isDialogOpen()) {
        clearInterval(this.dialogPollTimer);
        this.dialogPollTimer = null;
        this.processQueue();
      }
    }, 500);
  },

  startIdleTimer() {
    this.resetIdleTimer = () => {
      if (this.idleFired) return;
      if (this.idleTimer) clearTimeout(this.idleTimer);
      this.idleTimer = setTimeout(() => {
        this.idleFired = true;
        this.enqueueTip(TIP_IDS.IDLE_HELP);
      }, IDLE_TIMEOUT_MS);
    };

    this.idleEvents = ["keydown", "mousemove", "click"];
    this.idleEvents.forEach((evt) => {
      document.addEventListener(evt, this.resetIdleTimer, { passive: true });
    });

    this.resetIdleTimer();
  },

  removeIdleListeners() {
    if (this.idleEvents && this.resetIdleTimer) {
      this.idleEvents.forEach((evt) => {
        document.removeEventListener(evt, this.resetIdleTimer);
      });
    }
  },

  clearAllTimers() {
    if (this.autoDismissTimer) clearTimeout(this.autoDismissTimer);
    if (this.cooldownTimer) clearTimeout(this.cooldownTimer);
    if (this.idleTimer) clearTimeout(this.idleTimer);
    if (this.dialogPollTimer) clearInterval(this.dialogPollTimer);
  },
};

export default ContextualTipsHook;
