import { connectionView } from "./connection_view.js";

/**
 * DOM presentation for the connection status hook — controller, no LiveView.
 *
 * Owns the banner and reconnect-overlay DOM, the chat-input draft it preserves
 * across an outage, and the shell (menu bar) disabling. It takes the connection
 * state the machine reports, maps it through the pure `connectionView`, and
 * applies the result. The state machine, the browser online/offline listeners
 * and the server pushes stay in the hook. The overlay's action button is bound
 * here but its meaning (cancel vs. reload) is the hook's, delivered through the
 * `onActionClick` port.
 */
export function createConnectionStatusView(el, { onActionClick } = {}) {
  let banner, bannerText, overlay, overlayInfo, overlayCountdown, overlayAction;
  let onAction = null;
  let draftValue = "";

  function refreshElements() {
    banner = el.querySelector('[data-role="banner"]');
    bannerText = el.querySelector('[data-role="banner-text"]');
    overlay = el.querySelector('[data-role="overlay"]');
    overlayInfo = el.querySelector('[data-role="overlay-info"]');
    overlayCountdown = el.querySelector('[data-role="overlay-countdown"]');
    overlayAction = el.querySelector('[data-role="overlay-action"]');
  }

  function updateChatInputDisabled(disabled) {
    const input = document.querySelector('[data-testid="chat-input-field"]');
    const send = document.querySelector('[data-testid="chat-input-send"]');

    if (disabled && input) draftValue = input.value;
    if (!disabled) restoreDraftIfNeeded(input);

    if (input) input.disabled = disabled;
    if (send) send.disabled = disabled || !input || input.value.length === 0;
  }

  function restoreDraftIfNeeded(input) {
    if (!input || !draftValue) return;

    const restore = () => {
      if (input.value !== "") return;

      input.value = draftValue;
      input.dispatchEvent(new Event("input", { bubbles: true }));
    };

    restore();
    requestAnimationFrame(restore);
    setTimeout(restore, 50);
  }

  function updateShellDisabled(disabled) {
    const menuBar = document.querySelector('[data-testid="menu-bar"]');
    if (!menuBar) return;

    // Which menus go away offline is marked in the markup, not matched by
    // label: the labels are translated, so reading them only ever recognised
    // the English ones, and the trigger's text carries its icon too.
    menuBar.querySelectorAll("[data-menubar-trigger]").forEach((trigger) => {
      const shouldDisable = disabled && trigger.dataset.offlineDisabled === "true";

      trigger.dataset.disabled = shouldDisable ? "true" : "false";
      trigger.setAttribute("aria-disabled", shouldDisable ? "true" : "false");

      if (shouldDisable) {
        trigger.classList.remove("bg-primary", "text-primary-foreground");
      }
    });

    if (disabled) {
      menuBar.dispatchEvent(new CustomEvent("menubar:close-all"));
    }
  }

  return {
    mount() {
      refreshElements();
      onAction = () => onActionClick?.();
      overlayAction.addEventListener("click", onAction);
    },

    render(state, data) {
      const view = connectionView(state, data);

      banner.classList.remove(
        "connection-banner--visible",
        "connection-banner--disconnected",
        "connection-banner--reconnected",
      );
      if (view.banner.visible) {
        bannerText.textContent = view.banner.text;
        banner.classList.add(
          "connection-banner--visible",
          `connection-banner--${view.banner.variant}`,
        );
      }

      overlay.classList.remove("reconnect-overlay--visible");
      if (view.overlay.visible) {
        overlay.classList.add("reconnect-overlay--visible");
        overlayInfo.textContent = view.overlay.info;
        overlayCountdown.textContent = view.overlay.countdown;
        overlayAction.textContent = view.overlay.action;
      }

      updateChatInputDisabled(view.shellDisabled);
      updateShellDisabled(view.shellDisabled);
    },

    clearDraft() {
      draftValue = "";
    },

    destroy() {
      overlayAction?.removeEventListener("click", onAction);
    },
  };
}
