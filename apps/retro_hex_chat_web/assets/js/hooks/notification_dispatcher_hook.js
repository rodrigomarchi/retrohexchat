/**
 * LiveView hook for the central notification dispatcher.
 *
 * Wires server push events ("notify", "notification_batch") to the
 * client-side dispatcher which fans out to toast, sound, title flash,
 * browser notification, and favicon badge channels.
 *
 * Hook=wiring only — all logic lives in js/lib/ modules.
 */
import { createDispatcher } from "../lib/notification_dispatcher.js";
import { createNotificationToastManager } from "../lib/notification_toast.js";
import { createFaviconBadge } from "../lib/favicon_badge.js";
import * as browserNotif from "../lib/browser_notification.js";
import { loadPrefs, savePrefs } from "../lib/notification_prefs.js";

const NotificationDispatcherHook = {
  mounted() {
    this.prefs = loadPrefs();

    const toastContainer = document.getElementById("notification-toasts");

    this.toastManager = createNotificationToastManager({
      container: toastContainer,
      onNavigate: ({ channel }) => {
        if (channel) {
          this.pushEvent("navigate_to_channel", { channel });
        }
      },
    });

    this.faviconBadge = createFaviconBadge();

    this.dispatcher = createDispatcher({
      toast: this.toastManager,
      sound: {
        play: (type) => {
          this.pushEvent("play_notification_sound", { type });
        },
      },
      titleFlash: {
        start: (message) => {
          this.pushEvent("start_title_flash", { message });
        },
      },
      browserNotif,
      faviconBadge: this.faviconBadge,
    });

    this.handleEvent("notify", (event) => {
      const context = {
        activeChannel: this.el.dataset.activeChannel || null,
        tabVisible: !document.hidden,
      };
      this.dispatcher.dispatch(event, this.prefs, context);
    });

    this.handleEvent("notification_batch", (batch) => {
      this.dispatcher.dispatchBatch(batch, this.prefs);
    });

    this.handleEvent("update_notification_prefs", (newPrefs) => {
      this.prefs = { ...this.prefs, ...newPrefs };
      savePrefs(this.prefs);
    });

    this.handleEvent("clear_favicon_badge", () => {
      this.faviconBadge.clear();
    });
  },

  destroyed() {
    if (this.toastManager) {
      this.toastManager.clear();
    }
    if (this.faviconBadge) {
      this.faviconBadge.clear();
    }
  },
};

export default NotificationDispatcherHook;
