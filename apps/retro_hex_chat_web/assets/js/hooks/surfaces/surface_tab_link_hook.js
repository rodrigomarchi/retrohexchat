import { log } from "../../lib/logger.js";
import { openChannel, requestFocus } from "../../lib/surfaces/tab_registry.js";

/**
 * SurfaceTabLink — the link that says "go to the tab you already have".
 *
 * Whether the tab exists is the server's answer, and it is already baked into
 * the markup: this hook is only mounted on a link the server drew as "go to",
 * never on one it drew as "open in a tab". So the only question left here is
 * the one no server can answer — can that tab be brought to the front — and
 * the honest answer is "sometimes", because browsers refuse `focus()` from a
 * background tab and refuse it silently.
 *
 * So the click is intercepted, the tab is asked, and if nothing answers within
 * the deadline the element says so and stops intercepting. The second click
 * follows the href, which opens the tab the person asked for — that is the
 * right fallback, not a dead button.
 */
const SurfaceTabLinkHook = {
  mounted() {
    this._channel = openChannel();
    this._onClick = (event) => this._handleClick(event);
    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this._onClick);
    if (this._channel) this._channel.close();
  },

  _handleClick(event) {
    const path = this.el.dataset.surfacePath;
    if (!path || this._giveUp) return;

    event.preventDefault();

    requestFocus(this._channel, path).then((answered) => {
      if (answered) return;

      // Nobody came forward: the tab may be on another monitor, in another
      // window, or on another machine entirely. Say that, and let the next
      // click do what the link says.
      // `debug`, not `info`: the logger exposes debug/warn/error and is frozen,
      // so `log.info` threw a TypeError right here — inside a `.then`, where it
      // became an unhandled rejection that swallowed the two lines below it.
      // The note never appeared and nothing anywhere said why.
      log.debug("[surfaces] no tab answered the focus request", { path });
      this._giveUp = true;
      this._note("true");
    });
  },

  _note(visible) {
    const note = this.el.parentElement?.querySelector("[data-surface-tab-note]");
    if (note) note.dataset.visible = visible;
  },
};

export default SurfaceTabLinkHook;
