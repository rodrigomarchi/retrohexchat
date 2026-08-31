import { log } from "../../lib/logger.js";
import { answerFocusRequests, openChannel } from "../../lib/surfaces/tab_registry.js";

/**
 * SurfacePresence — this tab answers when the chat asks for it by address.
 *
 * Mounted on every surface that has an address of its own. It advertises
 * nothing and tracks nothing: the server already knows this tab exists, because
 * `RetroHexChat.Surfaces` monitors the process behind it. The only thing this
 * adds is the one capability the server does not have — pulling the window
 * forward — and it answers even when that is refused, because "a tab with this
 * address is here" is what the asker actually needs to know.
 */
const SurfacePresenceHook = {
  mounted() {
    this._channel = openChannel();
    this._stop = answerFocusRequests(this._channel, window.location.pathname, {
      focus: () => window.focus(),
      // `debug` rather than `info`, which the frozen logger does not have: a
      // throw here escapes the request handler and the grant below it is never
      // posted, so a browser that refuses focus would also stop answering.
      onError: (error) => log.debug("[surfaces] the browser refused to focus this tab", error),
    });
  },

  destroyed() {
    if (this._stop) this._stop();
    if (this._channel) this._channel.close();
  },
};

export default SurfacePresenceHook;
