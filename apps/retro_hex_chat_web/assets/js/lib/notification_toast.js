/**
 * Notification toast queue manager.
 *
 * Manages up to MAX_VISIBLE simultaneous toast notifications.
 * Auto-dismisses after DISMISS_MS. Click-to-navigate callback support.
 * P2P invite toasts have action buttons and no auto-dismiss.
 *
 * Reuses toast.js DOM builders for retro-styled toasts.
 */

import { createToastElement, animateIn, animateOut } from "./toast.js";

const MAX_VISIBLE = 3;
const DISMISS_MS = 5000;

/**
 * Create a notification toast manager.
 *
 * @param {Object} options
 * @param {HTMLElement} options.container - DOM container for toasts
 * @param {Function} [options.onNavigate] - Callback when toast is clicked (receives {channel, type})
 * @param {Function} [options.onP2pAction] - Callback for P2P invite actions (receives {action, token})
 * @returns {Object} Manager with show(), showBatch(), getVisibleCount()
 */
export function createNotificationToastManager(options = {}) {
  const { container, onNavigate, onP2pAction } = options;
  const visible = [];
  const queue = [];

  function show(notification) {
    if (visible.length >= MAX_VISIBLE) {
      queue.push(notification);
      return;
    }

    displayToast(notification);
  }

  function showBatch(count, channelCount) {
    show({
      id: "batch_" + Date.now(),
      title: "New Activity",
      body: `${count} new messages in ${channelCount} channels`,
      channel: null,
      type: "batch",
    });
  }

  function displayToast(notification) {
    if (!container) return;

    if (notification.type === "p2p_invite") {
      displayP2pInviteToast(notification);
      return;
    }

    const el = createToastElement({
      title: notification.title || "Notification",
      body: notification.body || "",
      dismissLabel: "",
      showCheckbox: false,
    });

    el.classList.add("notification-toast");
    el.dataset.notificationId = notification.id;

    // Click to navigate
    el.addEventListener("click", () => {
      dismiss(el, notification.id);
      if (onNavigate && notification.channel) {
        onNavigate({ channel: notification.channel, type: notification.type });
      }
    });

    container.appendChild(el);
    visible.push({ id: notification.id, el });
    animateIn(el);

    // Auto-dismiss
    const timer = setTimeout(() => {
      dismiss(el, notification.id);
    }, DISMISS_MS);

    el._dismissTimer = timer;
  }

  function displayP2pInviteToast(notification) {
    const el = createToastElement({
      title: notification.title || "Convite P2P",
      body: notification.body || "",
      dismissLabel: "",
      showCheckbox: false,
    });

    el.classList.add("notification-toast", "notification-toast--p2p");
    el.dataset.notificationId = notification.id;

    // Remove the default click behavior — we use buttons instead
    const bodyEl = el.querySelector(".toast-body") || el;

    const btnContainer = document.createElement("div");
    btnContainer.className = "notification-toast__actions";

    const acceptBtn = document.createElement("button");
    acceptBtn.className = "notification-toast__btn notification-toast__btn--accept";
    acceptBtn.textContent = "Accept";
    acceptBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      dismiss(el, notification.id);
      if (onP2pAction) {
        onP2pAction({ action: "accept", token: notification.token });
      } else {
        window.open(`/p2p/${notification.token}`, "_blank");
      }
    });

    const rejectBtn = document.createElement("button");
    rejectBtn.className = "notification-toast__btn notification-toast__btn--reject";
    rejectBtn.textContent = "Decline";
    rejectBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      dismiss(el, notification.id);
      if (onP2pAction) {
        onP2pAction({
          action: "reject",
          token: notification.token,
          from: notification.from,
        });
      }
    });

    const ignoreBtn = document.createElement("button");
    ignoreBtn.className = "notification-toast__btn notification-toast__btn--ignore";
    ignoreBtn.textContent = "Ignore";
    ignoreBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      dismiss(el, notification.id);
    });

    btnContainer.appendChild(acceptBtn);
    btnContainer.appendChild(rejectBtn);
    btnContainer.appendChild(ignoreBtn);
    bodyEl.appendChild(btnContainer);

    container.appendChild(el);
    visible.push({ id: notification.id, el });
    animateIn(el);

    // P2P invite toasts do NOT auto-dismiss (persistent)
  }

  function dismiss(el, id) {
    if (el._dismissTimer) {
      clearTimeout(el._dismissTimer);
    }

    const idx = visible.findIndex((v) => v.id === id);
    if (idx !== -1) {
      visible.splice(idx, 1);
    }

    animateOut(el, () => {
      if (el.parentNode) {
        el.parentNode.removeChild(el);
      }
      processQueue();
    });
  }

  function processQueue() {
    if (queue.length > 0 && visible.length < MAX_VISIBLE) {
      const next = queue.shift();
      displayToast(next);
    }
  }

  function getVisibleCount() {
    return visible.length;
  }

  function clear() {
    while (visible.length > 0) {
      const { el, id } = visible[0];
      dismiss(el, id);
    }
    queue.length = 0;
  }

  return { show, showBatch, getVisibleCount, clear };
}

export { MAX_VISIBLE, DISMISS_MS };
