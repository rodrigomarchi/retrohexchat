/**
 * LiveView binding for Hex Paint's window: creates the
 * `lib/paint/paint_controller.js` controller, writes its status fields, and
 * hands a finished picture to the window's upload when it is to be posted.
 *
 * Post opens the island's dialog first and uploads after, so the dialog is
 * already there to show the picture as it arrives.
 */
import { handToAsciiArt } from "../../lib/ascii_art/hand_off.js";
import { createPaint } from "../../lib/paint/paint_controller.js";
import { saveBlob } from "../../lib/save_blob.js";

export function createPaintHook({ factory = createPaint } = {}) {
  return {
    mounted() {
      const doc = this.el.ownerDocument;
      this.paint = factory(this.el, {
        // Read when used: a page with storage turned off throws on the read,
        // and the controller says so.
        storage: () => doc.defaultView?.localStorage ?? null,
        status: (name, text) => {
          const field = doc.querySelector(`[data-paint-status='${name}']`);
          if (field) field.textContent = text;
        },
        post: (file) => {
          this.pushEventTo(this.el, "paint_post_open", {});
          this.uploadTo(this.el, "drawing", [file]);
        },
        download: (blob, name) => {
          this.revokeSaved();
          this.saved = saveBlob(doc, blob, name);
        },
        openAscii: () => handToAsciiArt(doc, () => this.pushEvent("open_ascii_art", {})),
      });
      this.paint.mount();
    },

    revokeSaved() {
      if (this.saved) this.el.ownerDocument.defaultView.URL.revokeObjectURL(this.saved);
      this.saved = null;
    },

    destroyed() {
      this.paint?.destroy();
      this.revokeSaved();
    },
  };
}

export default createPaintHook();
