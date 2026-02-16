/**
 * ConnectForm hook — submits the hidden session form when the server
 * pushes the "submit_connect" event after successful nickname validation
 * or password authentication.
 */
const ConnectFormHook = {
  mounted() {
    this.handleEvent("submit_connect", () => {
      const form = document.getElementById("connect-session-form");
      if (form) form.requestSubmit();
    });
  },
};

export default ConnectFormHook;
