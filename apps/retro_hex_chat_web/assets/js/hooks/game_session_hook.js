/**
 * LiveView Hook: GameSessionHook
 *
 * Handles beforeunload cleanup for game sessions.
 * Sends game_leave event when the user navigates away.
 */
const GameSessionHook = {
  mounted() {
    this._beforeUnloadHandler = () => {
      this.pushEvent("game_leave", {});
    };

    window.addEventListener("beforeunload", this._beforeUnloadHandler);

    this.handleEvent("game_close_tab", () => {
      window.removeEventListener("beforeunload", this._beforeUnloadHandler);
      window.close();
    });
  },

  destroyed() {
    window.removeEventListener("beforeunload", this._beforeUnloadHandler);
  },
};

export default GameSessionHook;
