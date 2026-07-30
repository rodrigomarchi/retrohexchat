/**
 * LiveView hook owning the browser tab title.
 *
 * The base title comes from the server as `data-title` — the same string the
 * chat window's title bar shows — and is re-applied on every patch of this
 * element, which is how the tab follows the active conversation. On activity in
 * a non-active channel/PM the server pushes `title_flash_start`, and the title
 * alternates with that message until the tab is focused again.
 */
import { createDocumentTitle } from "../../lib/ui/document_title.js";
import { t } from "../../lib/i18n.js";

const DocumentTitleHook = {
  mounted() {
    this.title = createDocumentTitle();
    this.title.setBase(this.el.dataset.title);

    this.handleEvent("title_flash_start", ({ message }) => {
      this.title.startFlash(message || t("* New activity"));
    });

    this.handleEvent("title_flash_stop", () => {
      this.title.stopFlash();
    });

    this.onVisibilityChange = () => {
      if (!document.hidden) {
        this.pushEvent("tab_focused", {});
        this.title.stopFlash();
      }
    };

    document.addEventListener("visibilitychange", this.onVisibilityChange);
  },

  updated() {
    this.title.setBase(this.el.dataset.title);
  },

  destroyed() {
    document.removeEventListener("visibilitychange", this.onVisibilityChange);
    this.title.stopFlash();
  },
};

export default DocumentTitleHook;
