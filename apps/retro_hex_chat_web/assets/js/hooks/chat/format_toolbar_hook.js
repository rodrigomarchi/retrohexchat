/**
 * LiveView binding for the formatting toolbar.
 *
 * All behaviour lives in `lib/chat/format_toolbar.js`, which knows nothing about
 * LiveView — the popover, the B/I/U buttons, the colour dropdown and swatch
 * insertion. This binds it to the toolbar element and forwards the lifecycle.
 */
import { createFormatToolbar } from "../../lib/chat/format_toolbar.js";

export function createFormatToolbarHook({ factory = createFormatToolbar } = {}) {
  return {
    mounted() {
      this.toolbar = factory(this.el);
      this.toolbar.mount();
    },

    updated() {
      this.toolbar.reconcile();
    },

    destroyed() {
      this.toolbar.destroy();
    },
  };
}

export default createFormatToolbarHook();
