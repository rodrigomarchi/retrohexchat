/**
 * OptionsHook — applies CSS custom property overrides from server-side preferences.
 *
 * Handles the "apply_preferences" push_event by setting CSS custom properties
 * on document.documentElement, enabling real-time font and color changes
 * without page reload.
 */
const OptionsHook = {
  mounted() {
    this.handleEvent("apply_preferences", (payload) => {
      this.applyStyles(payload.styles || {});
    });
  },

  applyStyles(styles) {
    const root = document.documentElement;
    for (const [prop, value] of Object.entries(styles)) {
      root.style.setProperty(prop, value);
    }
  }
};

export default OptionsHook;
