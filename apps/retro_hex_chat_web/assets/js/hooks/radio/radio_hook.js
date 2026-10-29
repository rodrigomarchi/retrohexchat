/**
 * LiveView binding for Hex Radio's window: creates the
 * `lib/radio/radio_controller.js` player, writes its status fields, plays the
 * station the server chooses (`radio:play`) and keeps the favourites the
 * server hands back (`radio:favorites`), which it sends when the player is
 * ready (`radio_ready`) — the server's cue to list the first stations.
 */
import { keepFavorites, readFavorites } from "../../lib/radio/preferences.js";
import { createRadio } from "../../lib/radio/radio_controller.js";

export function createRadioHook({ factory = createRadio } = {}) {
  return {
    mounted() {
      const doc = this.el.ownerDocument;
      // Read when used: a page with storage turned off throws on the read.
      const storage = () => doc.defaultView?.localStorage ?? null;
      this.radio = factory(this.el, {
        storage,
        // The root and the keys are the server's: an attribute set plainly
        // would be wiped by its next patch, so it goes through LiveView.
        mark: (element, name, value) => this.js().setAttribute(element, name, value),
        status: (name, text) => {
          const field = doc.querySelector(`[data-radio-status='${name}']`);
          if (field) field.textContent = text;
        },
      });
      this.radio.mount();
      this.handleEvent("radio:play", (station) => this.radio.play(station));
      this.handleEvent("radio:favorites", ({ ids }) => keepFavorites(storage, ids));
      this.pushEventTo(this.el, "radio_ready", { ids: readFavorites(storage) });
    },

    destroyed() {
      this.radio?.destroy();
    },
  };
}

export default createRadioHook();
