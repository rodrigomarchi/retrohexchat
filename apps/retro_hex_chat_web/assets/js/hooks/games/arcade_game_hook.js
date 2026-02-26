/**
 * ArcadeGame hook — fullscreen game window.
 * Auto-focuses the iframe and signals the server when the window is closing.
 */
const ArcadeGameHook = {
  mounted() {
    const iframe = this.el.querySelector("iframe");

    if (iframe) {
      iframe.addEventListener("load", () => iframe.focus());
      iframe.addEventListener("mouseenter", () => iframe.focus());
    }

    // Signal server when window/tab is closing
    this._beforeUnload = () => {
      this.pushEvent("game_window_closing", {});
    };
    window.addEventListener("beforeunload", this._beforeUnload);

    // Handle server-pushed close event
    this.handleEvent("arcade_close_tab", () => {
      window.close();
    });
  },

  destroyed() {
    window.removeEventListener("beforeunload", this._beforeUnload);
  },
};

export default ArcadeGameHook;
