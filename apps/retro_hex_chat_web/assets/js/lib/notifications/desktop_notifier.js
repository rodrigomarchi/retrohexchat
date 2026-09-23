/**
 * Desktop notifications, and the three reasons not to raise one.
 *
 * The server already decided that this message is about you, in a conversation
 * you are not looking at, that you have not muted. What is left is the part
 * only the browser knows:
 *
 *   - the tab is in front, so the row is already on screen and a notification
 *     would say the same thing twice;
 *   - permission was never asked for, which must never happen on page load —
 *     browsers require a user gesture, and a prompt in the first second is the
 *     fastest way to be blocked for good;
 *   - permission was refused, which is final until the person changes it in
 *     their browser, so asking again is noise with no way to succeed.
 *
 * `tag` is the conversation, so a busy room replaces its own notification
 * instead of stacking one per line.
 */

const NO_NOTIFICATION_API = "unsupported";

/**
 * @param {Object} [deps]
 * @param {typeof Notification} [deps.notification] - injectable for tests
 * @param {Document} [deps.doc]
 * @returns {{permission: Function, request: Function, notify: Function, destroy: Function}}
 */
export function createDesktopNotifier(deps = {}) {
  const api = deps.notification ?? globalThis.Notification;
  const doc = deps.doc ?? globalThis.document;
  const open = new Map();

  function permission() {
    if (!api) return NO_NOTIFICATION_API;
    return api.permission;
  }

  function close(tag) {
    const existing = open.get(tag);
    if (!existing) return;
    open.delete(tag);
    try {
      existing.close();
    } catch (error) {
      // A notification the browser already dismissed throws on close. It is
      // gone either way, which is what the caller asked for.
      void error;
    }
  }

  return {
    permission,

    /**
     * Asks for permission. Call this from a user gesture and nowhere else.
     *
     * @returns {Promise<string>} the permission after the prompt
     */
    async request() {
      if (!api) return NO_NOTIFICATION_API;
      if (api.permission !== "default") return api.permission;
      return api.requestPermission();
    },

    /**
     * Raises one notification, or explains why it did not.
     *
     * @param {{title: string, body: string, tag: string}} message
     * @param {Function} [onClick] - called with the tag when the person clicks
     * @returns {string} "shown", "visible", "unsupported", or the permission
     */
    notify(message, onClick) {
      if (!api) return NO_NOTIFICATION_API;
      if (api.permission !== "granted") return api.permission;
      if (doc && doc.hidden === false) return "visible";

      close(message.tag);

      const notification = new api(message.title, {
        body: message.body,
        tag: message.tag,
      });

      notification.onclick = () => {
        close(message.tag);
        if (typeof onClick === "function") onClick(message.tag);
      };

      open.set(message.tag, notification);
      return "shown";
    },

    /** Closes everything this notifier raised. Mirrors what `notify` opened. */
    destroy() {
      for (const tag of [...open.keys()]) close(tag);
    },
  };
}
