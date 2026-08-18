/**
 * LiveView binding for the group-call pre-join dialog.
 *
 * The device enumeration, the camera preview and the preference reporting live
 * in `lib/group_call/prejoin.js`, which knows nothing about LiveView. This binds
 * it to the dialog element and gives it a pushEvent port.
 */
import { createGroupCallPreJoin } from "../../lib/group_call/prejoin.js";

export function createGroupCallPreJoinHook({ factory = createGroupCallPreJoin } = {}) {
  return {
    mounted() {
      this.prejoin = factory(this.el, {
        pushEvent: (event, payload) => this.pushEvent(event, payload),
      });
      this.prejoin.mount();
    },

    updated() {
      this.prejoin.reconcile();
    },

    destroyed() {
      this.prejoin.destroy();
    },
  };
}

export default createGroupCallPreJoinHook();
