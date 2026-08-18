/**
 * LiveView binding for scroll-position preservation.
 *
 * The coordination — capturing at the patch boundary and restoring after —
 * lives in `lib/ui/scroll_preservation.js`, shared with the morphdom callbacks
 * the app wires into LiveSocket. This hook registers its element with that
 * shared preserver and forwards the LiveView lifecycle.
 *
 * Mount on a stable child; `data-preserve-scroll-target` (self | parent | a
 * selector) names the scroll container, defaulting to the parent.
 */
import { scrollPreserver } from "../../lib/ui/scroll_preservation";

const PreserveScrollHook = {
  mounted() {
    this.preserver = scrollPreserver.register(this.el);
  },

  beforeUpdate() {
    this.preserver.beforeUpdate();
  },

  updated() {
    this.preserver.updated();
  },

  destroyed() {
    this.preserver.destroy();
  },
};

export default PreserveScrollHook;
