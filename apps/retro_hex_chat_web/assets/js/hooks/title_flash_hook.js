/**
 * LiveView hook for title bar activity flash.
 *
 * When activity arrives in a non-active channel/PM, the browser title
 * alternates between the original and an activity indicator.
 * Stops when the user focuses the tab.
 */

const TitleFlashHook = {
  mounted() {
    this.originalTitle = document.title;
    this.flashInterval = null;

    this.handleEvent("title_flash_start", ({ message }) => {
      this.startFlash(message || "* New activity");
    });

    this.handleEvent("title_flash_stop", () => {
      this.stopFlash();
    });

    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) {
        this.pushEvent("tab_focused", {});
        this.stopFlash();
      }
    });
  },

  startFlash(message) {
    if (this.flashInterval) return;

    this.originalTitle = document.title;
    let showActivity = true;

    this.flashInterval = setInterval(() => {
      document.title = showActivity
        ? `${message} - RetroHexChat`
        : this.originalTitle;
      showActivity = !showActivity;
    }, 1500);
  },

  stopFlash() {
    if (this.flashInterval) {
      clearInterval(this.flashInterval);
      this.flashInterval = null;
      document.title = this.originalTitle;
    }
  },

  destroyed() {
    this.stopFlash();
  },
};

export default TitleFlashHook;
