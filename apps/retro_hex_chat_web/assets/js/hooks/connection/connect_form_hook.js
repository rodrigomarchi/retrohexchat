/**
 * LiveView binding for the connect form.
 *
 * The client-field population, the device-label suggestion/rendering and the
 * remember-device panel live in `lib/connection/connect_form.js`. This binds it
 * and submits the hidden session form when the server pushes `submit_connect`.
 */
import { createConnectForm } from "../../lib/connection/connect_form.js";

export function createConnectFormHook({ factory = createConnectForm } = {}) {
  return {
    mounted() {
      this.form = factory(this.el);
      this.form.mount();
      this.handleEvent("submit_connect", () => this.form.submit());
    },

    updated() {
      this.form.reconcile();
    },
  };
}

export default createConnectFormHook();
