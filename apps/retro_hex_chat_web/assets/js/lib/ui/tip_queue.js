/**
 * The contextual-tips queue, toast lifecycle and idle detection — a controller,
 * no LiveView.
 *
 * Tips arrive one at a time, queue while one is showing or a dialog is open, and
 * a period of inactivity enqueues the idle-help tip. The tip-state decisions
 * live in lib/ui/tips.js and the toast DOM in lib/notifications/toast.js; this
 * owns the queue, the timers and the idle listeners. Seen and suppressed changes
 * go back to the caller through ports.
 *
 * @module ui/tip_queue
 */
import {
  isSuppressed,
  setSuppressed,
  loadTipsState,
  shouldShowTip,
  markTipSeen,
  markPreempted,
  getTipById,
  QUEUE_GAP_MS,
  AUTO_DISMISS_MS,
  IDLE_TIMEOUT_MS,
  TIP_IDS,
} from "./tips.js";
import { createToastElement, animateIn, animateOut } from "../notifications/toast.js";

/**
 * @param {object} ports
 * @param {HTMLElement} ports.host where toasts are appended
 * @param {(tipIds: string[]) => void} ports.onSeen
 * @param {(suppressed: boolean) => void} ports.onSuppressed
 * @param {() => boolean} [ports.isDialogOpen]
 */
export function createTipQueue({ host, onSeen, onSuppressed, isDialogOpen }) {
  const dialogOpen = isDialogOpen || (() => !!document.querySelector(".dialog-overlay"));

  const controller = {
    host,
    queue: [],
    isShowing: false,
    cooldownTimer: null,
    autoDismissTimer: null,
    idleTimer: null,
    idleFired: false,
    dialogPollTimer: null,
    currentToast: null,
    tipsDatasetKey: null,

    mount() {
      this.startIdleTimer();
    },

    destroy() {
      this.clearAllTimers();
      this.removeIdleListeners();
      this.removeCurrentToast();
    },

    /** A tip_trigger from the server: preempt on help, else enqueue. */
    trigger(tip) {
      if (tip === "help_used") {
        const seen = markPreempted(tip);
        if (seen.length > 0) onSeen(seen);
        return;
      }
      this.enqueueTip(tip);
    },

    loadState(raw) {
      if (raw === this.tipsDatasetKey) return;
      this.tipsDatasetKey = raw;
      loadTipsState(this.readTipsState(raw));
    },

    readTipsState(raw) {
      if (!raw) return {};
      try {
        const decoded = JSON.parse(raw);
        return decoded && typeof decoded === "object" ? decoded : {};
      } catch {
        return {};
      }
    },

    enqueueTip(tipId) {
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

      if (dialogOpen()) {
        this.startDialogPolling();
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
          onSuppressed(true);
          this.clearQueue();
        }
        this.dismissToast(tip.id);
      };

      const toastEl = createToastElement(tip, { showCheckbox: true, onDismiss });
      this.host.appendChild(toastEl);
      this.currentToast = toastEl;

      requestAnimationFrame(() => animateIn(toastEl));

      this.autoDismissTimer = setTimeout(() => this.dismissToast(tip.id), AUTO_DISMISS_MS);
    },

    async dismissToast(tipId) {
      if (this.autoDismissTimer) {
        clearTimeout(this.autoDismissTimer);
        this.autoDismissTimer = null;
      }

      if (markTipSeen(tipId)) onSeen([tipId]);

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

    startDialogPolling() {
      if (this.dialogPollTimer) return;
      this.dialogPollTimer = setInterval(() => {
        if (!dialogOpen()) {
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
      this.idleEvents.forEach((evt) =>
        document.addEventListener(evt, this.resetIdleTimer, { passive: true }),
      );

      this.resetIdleTimer();
    },

    removeIdleListeners() {
      if (this.idleEvents && this.resetIdleTimer) {
        this.idleEvents.forEach((evt) => document.removeEventListener(evt, this.resetIdleTimer));
      }
    },

    clearAllTimers() {
      if (this.autoDismissTimer) clearTimeout(this.autoDismissTimer);
      if (this.cooldownTimer) clearTimeout(this.cooldownTimer);
      if (this.idleTimer) clearTimeout(this.idleTimer);
      if (this.dialogPollTimer) clearInterval(this.dialogPollTimer);
    },
  };

  return controller;
}
