/**
 * HelpNav hook — wires the CHM-style Back/Forward controls to the browser
 * history. Topic navigation uses real per-topic URLs (LiveView `navigate`), so
 * every topic view is a genuine history entry; these controls just drive
 * `history.back()` / `history.forward()`.
 *
 * Mounted once on the always-present toolbar, it delegates on `document` so
 * `[data-help-nav="back|forward"]` triggers work from both the toolbar and the
 * menu bar (separate DOM subtrees).
 */
const HelpNavHook = {
  mounted() {
    this._onClick = (event) => {
      const trigger = event.target.closest("[data-help-nav]");
      if (!trigger) return;

      const direction = trigger.getAttribute("data-help-nav");
      if (direction === "back") {
        window.history.back();
      } else if (direction === "forward") {
        window.history.forward();
      }
    };

    document.addEventListener("click", this._onClick);
  },

  destroyed() {
    document.removeEventListener("click", this._onClick);
  },
};

export default HelpNavHook;
