/**
 * LiveView hook binding this browser's push subscription to the server's row.
 *
 * A subscription is a fact the browser owns and the server stores, so the two
 * have to be told about each other: the server hands over its public key when
 * the person asks to be subscribed, and the browser hands back the endpoint it
 * was given. Everything the hook does is that exchange — the decisions live in
 * `lib/notifications/push_subscriptions.js`.
 */
import { createPushSubscriptions } from "../../lib/notifications/push_subscriptions.js";

export function createPushSubscribeHook(deps = {}) {
  const build = deps.createPushSubscriptions ?? createPushSubscriptions;

  return {
    mounted() {
      this.push = build();

      this.handleEvent("push_subscribe", async ({ public_key: publicKey }) => {
        const result = await this.push.subscribe(publicKey);

        if (result.ok) {
          this.pushEvent("push_subscription_created", result.subscription);
        } else {
          this.pushEvent("push_subscription_failed", { reason: result.reason });
        }
      });

      this.handleEvent("push_unsubscribe", async () => {
        const result = await this.push.unsubscribe();
        this.pushEvent("push_subscription_removed", { endpoint: result.endpoint ?? null });
      });

      this.reportState();
    },

    async reportState() {
      const state = await this.push.current();
      this.pushEvent("push_subscription_state", state);
    },
  };
}

export default createPushSubscribeHook();
