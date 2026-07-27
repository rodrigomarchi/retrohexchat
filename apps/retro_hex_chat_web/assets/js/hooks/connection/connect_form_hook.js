/**
 * ConnectForm hook — submits the hidden session form when the server
 * pushes the "submit_connect" event after successful nickname validation
 * or password authentication.
 *
 * Also detects the browser timezone and injects it into the hidden form
 * so that the session cookie carries the user's timezone.
 */
import { getClientInfo } from "../../lib/connection/client_info";

const ConnectFormHook = {
  mounted() {
    this.populateClientFields();

    this.handleEvent("submit_connect", () => {
      this.populateClientFields();
      const form = document.getElementById("connect-session-form");
      if (form) form.requestSubmit();
    });
  },

  populateClientFields() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "Etc/UTC";
    const tzInput = document.getElementById("connect-timezone-input");
    if (tzInput) tzInput.value = tz;

    const clientInfoInput = document.getElementById("connect-client-info-input");
    if (clientInfoInput) clientInfoInput.value = JSON.stringify(getClientInfo());
  },
};

export default ConnectFormHook;
