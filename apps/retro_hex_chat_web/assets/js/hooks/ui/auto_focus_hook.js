/**
 * Focuses its element on mount, on the next frame so it wins over any focus the
 * initial render placed elsewhere.
 */
const AutoFocusHook = {
  mounted() {
    requestAnimationFrame(() => this.el.focus());
  },
};

export default AutoFocusHook;
