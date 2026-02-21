/**
 * LiveView hook for auto-reconnect overlay.
 *
 * Observes the `phx-loading` class that Phoenix LiveView adds to the
 * main container when the WebSocket is disconnected. Shows a 98.css-styled
 * overlay with countdown and attempt tracking. Phoenix LiveView handles
 * the actual reconnection logic — this hook is purely visual.
 */
import { getBackoffDelay, RECONNECT_DEFAULTS } from "../lib/reconnect.js";

const ReconnectHook = {
  mounted() {
    this.attempt = 0;
    this.maxAttempts = RECONNECT_DEFAULTS.maxAttempts;
    this.maxDelay = RECONNECT_DEFAULTS.maxDelay;
    this.enabled = true;
    this.overlay = null;
    this.countdownTimer = null;
    this.cancelled = false;
    this.wasDisconnected = false;

    this.handleEvent("intentional_disconnect", () => {
      localStorage.setItem("rhc_intentional_disconnect", "true");
      localStorage.removeItem("rhc_reconnect_state");
    });

    this.handleEvent("save_reconnect_state", (data) => {
      localStorage.setItem("rhc_reconnect_state", JSON.stringify(data));
    });

    this.handleEvent("clear_client_state", () => {
      Object.keys(localStorage)
        .filter((k) => k.startsWith("rhc_"))
        .forEach((k) => localStorage.removeItem(k));
    });

    this.maybePushRestoreSession();
    this.setupObserver();
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
    this.clearCountdown();
    this.removeOverlay();
  },

  setupObserver() {
    const liveViewEl =
      document.querySelector("[data-phx-main]") || document.querySelector("[data-phx-session]");

    if (!liveViewEl) return;

    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "attributes" && mutation.attributeName === "class") {
          const hasLoading = liveViewEl.classList.contains("phx-loading");

          if (hasLoading && !this.wasDisconnected) {
            this.handleDisconnect();
          } else if (!hasLoading && this.wasDisconnected) {
            this.handleReconnect();
          }
        }
      }
    });

    this.observer.observe(liveViewEl, {
      attributes: true,
      attributeFilter: ["class"],
    });
  },

  handleDisconnect() {
    if (localStorage.getItem("rhc_intentional_disconnect") === "true") {
      localStorage.removeItem("rhc_intentional_disconnect");
      return;
    }

    if (!this.enabled) return;

    this.wasDisconnected = true;
    this.cancelled = false;
    this.attempt = 0;
    this.startReconnectCycle();
  },

  handleReconnect() {
    this.wasDisconnected = false;
    this.attempt = 0;
    this.cancelled = false;
    this.clearCountdown();
    this.removeOverlay();
    this.maybePushRestoreSession();
  },

  maybePushRestoreSession() {
    const raw = localStorage.getItem("rhc_reconnect_state");
    if (!raw) return;

    try {
      const state = JSON.parse(raw);
      localStorage.removeItem("rhc_reconnect_state");
      this.pushEvent("restore_session", state);
    } catch {
      localStorage.removeItem("rhc_reconnect_state");
    }
  },

  startReconnectCycle() {
    if (this.cancelled || !this.wasDisconnected) return;

    this.attempt++;

    if (this.attempt > this.maxAttempts) {
      this.showFailedOverlay();
      return;
    }

    const delay = this.getBackoffDelay(this.attempt);
    this.showCountdownOverlay(delay);
  },

  getBackoffDelay(attempt) {
    return getBackoffDelay(attempt, this.maxDelay);
  },

  showCountdownOverlay(delaySecs) {
    this.removeOverlay();

    let remaining = delaySecs;

    this.overlay = document.createElement("div");
    this.overlay.className = "reconnect-overlay";
    this.overlay.innerHTML = `
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Connection Lost</div>
        </div>
        <div class="window-body">
          <p class="attempt-info">Reconnection attempt ${this.attempt} of ${this.maxAttempts}</p>
          <p class="countdown">Reconnecting in ${remaining}s...</p>
          <div style="margin-top: 12px;">
            <button class="reconnect-cancel-btn">Cancel</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(this.overlay);

    const countdownEl = this.overlay.querySelector(".countdown");
    const cancelBtn = this.overlay.querySelector(".reconnect-cancel-btn");

    cancelBtn.addEventListener("click", () => {
      this.handleCancel();
    });

    this.countdownTimer = setInterval(() => {
      remaining--;
      if (remaining <= 0) {
        this.clearCountdown();
        if (!this.cancelled && this.wasDisconnected) {
          this.startReconnectCycle();
        }
      } else if (countdownEl) {
        countdownEl.textContent = `Reconnecting in ${remaining}s...`;
      }
    }, 1000);
  },

  showFailedOverlay() {
    this.removeOverlay();
    this.clearCountdown();
    window.location.href = "/connect?reason=expired";
  },

  handleCancel() {
    this.cancelled = true;
    this.clearCountdown();
    this.removeOverlay();

    this.overlay = document.createElement("div");
    this.overlay.className = "reconnect-overlay";
    this.overlay.innerHTML = `
      <div class="window">
        <div class="title-bar">
          <div class="title-bar-text">Connection Lost</div>
        </div>
        <div class="window-body">
          <p>Reconnection cancelled. Refresh to try again.</p>
          <div style="margin-top: 12px;">
            <button class="reconnect-refresh-btn">Refresh</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(this.overlay);

    this.overlay.querySelector(".reconnect-refresh-btn").addEventListener("click", () => {
      window.location.reload();
    });
  },

  clearCountdown() {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = null;
    }
  },

  removeOverlay() {
    if (this.overlay) {
      this.overlay.remove();
      this.overlay = null;
    }
  },
};

export default ReconnectHook;
