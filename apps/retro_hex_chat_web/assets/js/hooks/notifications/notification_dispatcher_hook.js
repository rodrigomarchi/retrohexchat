/**
 * LiveView hook for the central notification dispatcher.
 *
 * Wires server push events ("notify", "notification_batch") to the
 * client-side dispatcher which fans out to toast, sound, title flash,
 * browser notification, and favicon badge channels.
 *
 * Hook=wiring only — all logic lives in js/lib/ modules.
 */
import { createDispatcher } from "../../lib/notifications/notification_dispatcher.js";
import { createNotificationToastManager } from "../../lib/notifications/notification_toast.js";
import { createFaviconBadge } from "../../lib/ui/favicon_badge.js";
import * as browserNotif from "../../lib/notifications/browser_notification.js";
import { loadPrefs, savePrefs } from "../../lib/notifications/notification_prefs.js";
import { SOUND_CATALOG, synthesizeSound } from "../../lib/input/sound.js";
import { createTitleFlasher } from "../../lib/ui/title_flash.js";

const NotificationDispatcherHook = {
  mounted() {
    this.prefs = loadPrefs();
    this.audioCtx = null;
    this.titleFlasher = createTitleFlasher();

    const toastContainer = document.getElementById("notification-toasts");

    this.toastManager = createNotificationToastManager({
      container: toastContainer,
      onNavigate: ({ channel }) => {
        if (channel) {
          this.pushEvent("navigate_to_channel", { channel });
        }
      },
      onP2pAction: ({ action, token, from, type }) => {
        if (action === "accept") {
          if (type === "game_invite") {
            this.pushEvent("accept_game", { token });
          } else {
            this.pushEvent("accept_p2p", { token });
          }
        } else if (action === "reject") {
          this.pushEvent("reject_p2p", { token, from: from || "" });
        }
      },
    });

    this.faviconBadge = createFaviconBadge();

    const muted = localStorage.getItem("retro_hex_chat_mute") === "true";

    this.dispatcher = createDispatcher({
      toast: this.toastManager,
      sound: {
        play: (type) => {
          if (muted) return;
          if (!SOUND_CATALOG[type]) return;
          if (!this.audioCtx) {
            this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
          }
          synthesizeSound(this.audioCtx, type);
        },
      },
      titleFlash: this.titleFlasher,
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
    if (this.titleFlasher) {
      this.titleFlasher.stop();
    }
  },
};

export default NotificationDispatcherHook;
