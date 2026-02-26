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
 * handles the arcade_close_tab event and opens game windows.
 */
const ArcadeSessionHook = {
  mounted() {
    this._gameWindow = null;
    this._windowPoll = null;

    this.handleEvent("arcade_close_tab", () => {
      this._stopWindowPoll();
      closeArcadeTab();
    });

    this.handleEvent("open_game_window", ({ url }) => {
      this._gameWindow = window.open(url, "_blank");

      if (!this._gameWindow) {
        this.pushEvent("game_window_blocked", {});
        return;
      }

      this._startWindowPoll();
    });
  },

  destroyed() {
    this._stopWindowPoll();
  },

  _isWindowClosed() {
    try {
      return this._gameWindow.closed;
    } catch {
      // Cross-origin or detached window — treat as closed
      return true;
    }
  },

  _startWindowPoll() {
    this._stopWindowPoll();
    this._windowPoll = setInterval(() => {
      if (this._gameWindow && this._isWindowClosed()) {
        this._stopWindowPoll();
        this._gameWindow = null;
        this.pushEvent("game_window_closed", {});
      }
    }, 1000);
  },

  _stopWindowPoll() {
    if (this._windowPoll) {
      clearInterval(this._windowPoll);
      this._windowPoll = null;
    }
  },
};

export default ArcadeIframeHook;
export { ArcadeSessionHook };
