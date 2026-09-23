/**
 * LiveView hook binding the desktop notifier to the server's decisions.
 *
 * The server says *whether* a message is worth a notification; the notifier
 * says whether the browser is in a state to raise one. This is only the wire
 * between them, plus the one thing that must come from a real click: asking
 * for permission.
 */
import { createDesktopNotifier } from "../../lib/notifications/desktop_notifier.js";

export function createDesktopNotifyHook(deps = {}) {
  const build = deps.createNotifier ?? createDesktopNotifier;

  return {
    mounted() {
      this.notifier = build();

      this.handleEvent("desktop_notify", (message) => {
        this.notifier.notify(message, (conversation) =>
          this.pushEvent("desktop_notify_click", { conversation }),
        );
      });

      // Only ever in response to the person ticking the box: browsers require
      // a gesture, and a prompt on page load is how a site gets blocked.
      this.handleEvent("desktop_notify_request_permission", async () => {
        const permission = await this.notifier.request();
        this.pushEvent("desktop_notify_permission", { permission });
      });

      this.pushEvent("desktop_notify_permission", {
        permission: this.notifier.permission(),
      });
    },

    destroyed() {
      this.notifier?.destroy();
    },
  };
}

export default createDesktopNotifyHook();
