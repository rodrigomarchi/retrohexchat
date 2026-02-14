/**
 * LiveView hook for title bar activity flash.
 *
 * When activity arrives in a non-active channel/PM, the browser title
 * alternates between the original and an activity indicator.
 * Stops when the user focuses the tab.
 */
import { createTitleFlasher } from "../lib/title_flash.js";

const TitleFlashHook = {
  mounted() {
    this.flasher = createTitleFlasher();

    this.handleEvent("title_flash_start", ({ message }) => {
      this.flasher.start(message || "* New activity");
    });

    this.handleEvent("title_flash_stop", () => {
      this.flasher.stop();
    });

    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) {
        this.pushEvent("tab_focused", {});
        this.flasher.stop();
      }
    });
  },

  destroyed() {
    this.flasher.stop();
  },
};

export default TitleFlashHook;
