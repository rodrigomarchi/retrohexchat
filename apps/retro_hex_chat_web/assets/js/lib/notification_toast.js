/**
 * Notification toast queue manager.
 *
 * Manages up to MAX_VISIBLE simultaneous toast notifications.
 * Auto-dismisses after DISMISS_MS. Click-to-navigate callback support.
 *
 * Reuses toast.js DOM builders for 98.css-styled toasts.
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
 * @returns {Object} Manager with show(), showBatch(), getVisibleCount()
 */
export function createNotificationToastManager(options = {}) {
  const { container, onNavigate } = options;
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
