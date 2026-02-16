/**
 * Browser Notification API wrapper.
 *
 * Handles permission flow and notification display.
 * Never auto-requests permission — only via explicit requestPermission() call.
 */

/**
 * Check if the Notification API is supported.
 * @returns {boolean}
 */
export function isSupported() {
  return typeof Notification !== "undefined";
}

/**
 * Get current notification permission state.
 * @returns {"granted"|"denied"|"default"|"unsupported"}
 */
export function getPermission() {
  if (!isSupported()) return "unsupported";
  return Notification.permission;
}

/**
 * Request notification permission from the user.
 * Only call this from a user-initiated action (e.g., settings toggle).
 *
 * @returns {Promise<"granted"|"denied"|"default">}
 */
export async function requestPermission() {
  if (!isSupported()) return "unsupported";

  try {
    const result = await Notification.requestPermission();
    return result;
  } catch {
    return "denied";
  }
}

/**
 * Show a browser notification if permission is granted.
 * Falls back silently if permission is not granted.
 *
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Function} [onClick] - Optional click callback
 * @returns {Notification|null}
 */
export function show(title, body, onClick) {
  if (!isSupported() || getPermission() !== "granted") {
    return null;
  }

  try {
    const notification = new Notification(title, {
      body,
      icon: "/favicon.ico",
      tag: "retro-hex-chat",
    });

    if (onClick) {
      notification.onclick = () => {
        onClick();
        notification.close();
      };
    }

    return notification;
  } catch {
    return null;
  }
}
