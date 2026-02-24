/**
 * ConnectForm hook — submits the hidden session form when the server
 * pushes the "submit_connect" event after successful nickname validation
 * or password authentication.
 *
 * Also detects the browser timezone and injects it into the hidden form
 * so that the session cookie carries the user's timezone.
 */
const ConnectFormHook = {
  mounted() {
    // Detect browser timezone and populate the hidden field immediately
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || "Etc/UTC";
    const tzInput = document.getElementById("connect-timezone-input");
    if (tzInput) tzInput.value = tz;

    this.handleEvent("submit_connect", () => {
      const form = document.getElementById("connect-session-form");
      if (form) form.requestSubmit();
    });
  },
};

export default ConnectFormHook;
