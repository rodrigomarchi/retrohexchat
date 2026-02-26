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
      window.location.href = "/chat";
    });
  },
};

export default ArcadeIframeHook;
