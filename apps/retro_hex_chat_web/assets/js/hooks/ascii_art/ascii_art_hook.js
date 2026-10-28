/**
 * LiveView binding for ASCII Art's window: creates the
 * `lib/ascii_art/ascii_controller.js` controller, writes its status field,
 * copies the art and hands it to the window's island to be posted.
 */
import { createAsciiArt } from "../../lib/ascii_art/ascii_controller.js";
import { copyText } from "../../lib/ui/dom.js";

export function createAsciiArtHook({ factory = createAsciiArt } = {}) {
  return {
    mounted() {
      const doc = this.el.ownerDocument;
      this.art = factory(this.el, {
        // Read when used: a page with storage turned off throws on the read.
        storage: () => doc.defaultView?.localStorage ?? null,
        session: () => doc.defaultView?.sessionStorage ?? null,
        status: (name, text) => {
          const field = doc.querySelector(`[data-ascii-status='${name}']`);
          if (field) field.textContent = text;
        },
        copy: (text) => copyText(text),
        post: (art) => this.pushEventTo(this.el, "ascii_post_open", { art }),
      });
      this.art.mount();
    },

    destroyed() {
      this.art?.destroy();
    },
  };
}

export default createAsciiArtHook();
