/**
 * Closes the arcade tab/window.
 */
function closeArcadeTab() {
  window.close();
}

/**
 * ArcadeIframe hook — auto-focuses the iframe so keyboard/mouse input
 * reaches the Emscripten canvas immediately, and handles the
 * arcade_close_tab server event.
 */
const ArcadeIframeHook = {
  mounted() {
    const iframe = this.el;

    // Focus the iframe once it loads so keystrokes reach the game
    iframe.addEventListener("load", () => {
      iframe.focus();
    });

    // Also focus on click (in case focus was lost)
    iframe.addEventListener("mouseenter", () => {
      iframe.focus();
    });

    // Handle server-pushed close event
    this.handleEvent("arcade_close_tab", () => {
      closeArcadeTab();
    });
  },
};

/**
 * ArcadeSession hook — attached to the solo session container,
 * handles the arcade_close_tab event when no iframe is present (lobby view).
 */
const ArcadeSessionHook = {
  mounted() {
    this.handleEvent("arcade_close_tab", () => {
      closeArcadeTab();
    });
  },
};

export default ArcadeIframeHook;
export { ArcadeSessionHook };
