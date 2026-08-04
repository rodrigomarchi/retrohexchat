/**
 * NickChangeFormHook — submits the hidden session form when the server
 * pushes the "submit_nick_change" event after nick change confirmation.
 */
const NickChangeFormHook = {
  mounted() {
    this.handleEvent("submit_nick_change", () => {
      const form = document.getElementById("nick-change-session-form");
      if (form) form.requestSubmit();
    });
  },
};

export default NickChangeFormHook;
