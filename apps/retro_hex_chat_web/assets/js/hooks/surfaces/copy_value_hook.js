import { copyText } from "../../lib/ui/dom.js";
import { showFeedbackToast } from "../../lib/notifications/feedback_toast.js";
import { log } from "../../lib/logger.js";

/**
 * CopyValue — copies the text sitting next to it, wherever that is.
 *
 * The chat has always been able to copy: a menu item pushes `clipboard_copy`
 * and the chat's viewport hook receives it. A surface in a tab of its own has
 * no viewport hook, so that event arrived nowhere — which is why the share bar
 * has shown a readonly field instead of a Copy button ever since wave 1.
 *
 * The fix is not a second receiver for that event. The text is already in the
 * document, so nothing has to travel to the server and back to be copied: this
 * reads the field it points at and copies it, on any screen, with no round
 * trip and nothing for a satellite to be missing.
 */
const CopyValueHook = {
  mounted() {
    this._onClick = () => this._copy();
    this.el.addEventListener("click", this._onClick);
  },

  destroyed() {
    this.el.removeEventListener("click", this._onClick);
  },

  _copy() {
    const source = document.getElementById(this.el.dataset.copyFrom || "");
    const text = source && (source.value || source.textContent);
    if (!text) return;

    copyText(text)
      .then(() => showFeedbackToast(this.el, this.el.dataset.copiedLabel, 2000))
      .catch((error) =>
        // A refused clipboard is the one thing worth saying out loud: the field
        // is still there to select by hand, but the button looked like it
        // worked.
        log.warn("[surfaces] the browser refused the clipboard", error),
      );
  },
};

export default CopyValueHook;
