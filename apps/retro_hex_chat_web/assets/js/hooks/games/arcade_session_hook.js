/**
 * Closes the arcade tab/window.
 */
function closeArcadeTab() {
  window.close();
}

/**
 * ArcadeSession hook — anchored on the in-chat arcade session element. Opens the
 * selected WASM game in a separate browser window on `open_game_window`, polls it
 * and reports `game_window_closed`/`game_window_blocked` back to the LiveView so
 * the host can finish the solo session. The host can also ask it to close the
 * owned game window when the user returns to the launcher or ends the session.
 * Also handles the `arcade_close_tab` server event (legacy standalone-tab
 * close; harmless in the chat context).
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

    this.handleEvent("close_game_window", () => {
      this._closeGameWindow();
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

  _closeGameWindow() {
    this._stopWindowPoll();

    if (!this._gameWindow) {
      return;
    }

    try {
      if (!this._gameWindow.closed) {
        this._gameWindow.close();
      }
    } catch (error) {
      console.warn("Could not close arcade game window", error);
    }

    this._gameWindow = null;
  },
};

export default ArcadeSessionHook;
