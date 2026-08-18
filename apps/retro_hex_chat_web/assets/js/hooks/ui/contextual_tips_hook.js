/**
 * LiveView binding for contextual tips.
 *
 * The queue, the toast lifecycle and idle detection live in
 * `lib/ui/tip_queue.js`, which knows nothing about LiveView. This hook feeds it
 * the server's tip triggers and dataset state, and forwards seen/suppressed
 * changes back to the server.
 */
import { createTipQueue } from "../../lib/ui/tip_queue.js";

export function createContextualTipsHook({ factory = createTipQueue } = {}) {
  return {
    mounted() {
      this.tips = factory({
        host: this.el,
        onSeen: (tips) => this.pushEvent("tips_seen", { tips }),
        onSuppressed: (suppressed) => this.pushEvent("tips_suppressed_changed", { suppressed }),
      });
      this.tips.loadState(this.el.dataset.tipsState || "");
      this.tips.mount();

      this.handleEvent("tip_trigger", ({ tip }) => this.tips.trigger(tip));
    },

    updated() {
      this.tips.loadState(this.el.dataset.tipsState || "");
    },

    destroyed() {
      this.tips.destroy();
    },
  };
}

export default createContextualTipsHook();
