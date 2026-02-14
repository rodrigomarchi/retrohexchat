/**
 * OptionsHook — applies CSS custom property overrides from server-side preferences.
 *
 * Handles the "apply_preferences" push_event by setting CSS custom properties
 * on document.documentElement, enabling real-time font and color changes
 * without page reload.
 */
import { applyCSSProperties } from "../lib/dom.js";

const OptionsHook = {
  mounted() {
    this.handleEvent("apply_preferences", (payload) => {
      applyCSSProperties(payload.styles || {});
    });
  },
};

export default OptionsHook;
