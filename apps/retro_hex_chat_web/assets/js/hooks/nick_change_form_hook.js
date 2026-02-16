/**
 * NickChangeFormHook — submits the hidden session form when the server
 * pushes the "submit_nick_change" event after nick change confirmation.
 */
const NickChangeFormHook = {
  mounted() {
    this.handleEvent("submit_nick_change", () => {
      localStorage.removeItem("rhc_reconnect_state");
      const form = document.getElementById("nick-change-session-form");
      if (form) form.requestSubmit();
    });
  },
};

export default NickChangeFormHook;
