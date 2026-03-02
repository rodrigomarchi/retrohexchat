/**
 * ViewportDetectHook — sends viewport width to the server on mount
 * so the server can adjust defaults for mobile (e.g., close sidebars).
 */
export default {
  mounted() {
    this.pushEvent("viewport_info", { width: window.innerWidth });
  },
};
