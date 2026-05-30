/**
 * NickChangeFormHook — submits the hidden session form when the server
 * pushes the "submit_nick_change" event after nick change confirmation.
 */
const NickChangeFormHook = {
  mounted() {
    this.handleEvent("submit_nick_change", (payload = {}) => {
      this._retargetReconnectState(payload.previous_nickname, payload.nickname);
      const form = document.getElementById("nick-change-session-form");
      if (form) form.requestSubmit();
    });
  },

  _retargetReconnectState(previousNickname, nextNickname) {
    if (!previousNickname || !nextNickname) {
      localStorage.removeItem("rhc_reconnect_state");
      return;
    }

    const raw = localStorage.getItem("rhc_reconnect_state");
    if (!raw) return;

    try {
      const state = JSON.parse(raw);

      if (state.nickname !== previousNickname) {
        localStorage.removeItem("rhc_reconnect_state");
        return;
      }

      state.nickname = nextNickname;
      localStorage.setItem("rhc_reconnect_state", JSON.stringify(state));
    } catch {
      localStorage.removeItem("rhc_reconnect_state");
    }
  },
};

export default NickChangeFormHook;
