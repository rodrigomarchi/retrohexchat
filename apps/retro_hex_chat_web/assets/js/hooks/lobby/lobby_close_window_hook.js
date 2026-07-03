/**
 * LobbyCloseWindow — closes the current browser tab when its element is clicked.
 *
 * A lobby link opens in its own tab (session-card links use target="_blank"), so
 * the terminal-state "Close window" button dismisses that tab instead of
 * navigating it to /chat — the chat is single-instance, and pointing this tab at
 * it would evict a chat already open in another tab.
 *
 * window.close() only succeeds for script-closable contexts (a tab opened from a
 * link or script). If the tab was reached by typing the URL directly it silently
 * no-ops, so we fall back to navigating to /chat as the only sensible exit.
 */
const LobbyCloseWindowHook = {
  mounted() {
    this._onClick = () => {
      window.close();

      // window.close() is a no-op for non-script-closable tabs; if we are still
      // here a moment later, this tab was opened directly — send it to the chat.
      window.setTimeout(() => {
        if (!window.closed) window.location.assign("/chat");
      }, 100);
    };

    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this._onClick);
  },
};

export default LobbyCloseWindowHook;
