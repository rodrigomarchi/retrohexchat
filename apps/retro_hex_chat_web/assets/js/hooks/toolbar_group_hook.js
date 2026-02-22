/**
 * LiveView hook for collapsible toolbar groups.
 *
 * Each group has a toggle button (.toolbar-group-toggle) that shows/hides
 * its dropdown (.toolbar-group-dropdown). Uses mousedown with preventDefault()
 * to avoid stealing focus from the chat input.
 */
const ToolbarGroupHook = {
  mounted() {
    this.el.addEventListener("mousedown", (e) => {
      const toggle = e.target.closest(".toolbar-group-toggle");
      if (!toggle) return;
      e.preventDefault();

      const group = toggle.closest(".toolbar-group");
      const dropdown = group && group.querySelector(".toolbar-group-dropdown");
      if (!dropdown) return;

      const wasHidden = dropdown.classList.contains("u-hidden");
      this.closeAll();
      if (wasHidden) dropdown.classList.remove("u-hidden");
    });

    this.el.addEventListener("click", (e) => {
      if (e.target.closest(".toolbar-group-dropdown .toolbar-btn")) {
        this.closeAll();
      }
    });

    this._onOutside = (e) => {
      if (!this.el.contains(e.target)) this.closeAll();
    };
    this._onEscape = (e) => {
      if (e.key === "Escape") this.closeAll();
    };
    document.addEventListener("mousedown", this._onOutside);
    document.addEventListener("keydown", this._onEscape);
  },

  destroyed() {
    document.removeEventListener("mousedown", this._onOutside);
    document.removeEventListener("keydown", this._onEscape);
  },

  closeAll() {
    this.el.querySelectorAll(".toolbar-group-dropdown").forEach((d) => d.classList.add("u-hidden"));
  },
};

export default ToolbarGroupHook;
