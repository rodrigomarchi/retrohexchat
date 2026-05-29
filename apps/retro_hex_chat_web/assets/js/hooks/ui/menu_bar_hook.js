/**
 * LiveView hook for macOS-style menu bar with dropdown menus.
 *
 * Behaviour:
 * - Click a trigger to open its dropdown (toggles if already open)
 * - Hover over another trigger while a menu is open to switch ("hot tracking")
 * - Click a dropdown item to fire its action and close all menus
 * - Click outside or press Escape to close all menus
 * - Triggers with data-disabled are non-interactive
 *
 * Uses mousedown with preventDefault() to avoid stealing focus from chat input.
 */
const MenuBarHook = {
  mounted() {
    this._activeMenu = null;

    this.el.addEventListener("mousedown", (e) => {
      const trigger = e.target.closest("[data-menubar-trigger]");
      if (!trigger) return;
      e.preventDefault();

      if (trigger.dataset.disabled === "true") return;

      const menu = trigger.parentElement;
      if (this._activeMenu === menu) {
        this._closeAll();
      } else {
        this._openMenu(menu);
      }
    });

    // Hot tracking: hover switches menus when one is already open
    this.el.addEventListener(
      "mouseenter",
      (e) => {
        if (!this._activeMenu) return;
        const trigger = e.target.closest("[data-menubar-trigger]");
        if (!trigger || trigger.dataset.disabled === "true") return;
        const menu = trigger.parentElement;
        if (menu !== this._activeMenu) this._openMenu(menu);
      },
      true,
    );

    // Click on a dropdown item closes all menus
    this.el.addEventListener("click", (e) => {
      if (e.target.closest("[data-menubar-dropdown] li")) this._closeAll();
    });

    this._onOutside = (e) => {
      if (!this.el.contains(e.target)) this._closeAll();
    };
    this._onEscape = (e) => {
      if (e.key === "Escape") this._closeAll();
    };
    this._onForceClose = () => this._closeAll();
    document.addEventListener("mousedown", this._onOutside);
    document.addEventListener("keydown", this._onEscape);
    this.el.addEventListener("menubar:close-all", this._onForceClose);
  },

  destroyed() {
    document.removeEventListener("mousedown", this._onOutside);
    document.removeEventListener("keydown", this._onEscape);
    this.el.removeEventListener("menubar:close-all", this._onForceClose);
  },

  _openMenu(menu) {
    this._closeAll();
    const dropdown = menu.querySelector("[data-menubar-dropdown]");
    if (!dropdown) return;
    dropdown.classList.remove("u-hidden");
    const trigger = menu.querySelector("[data-menubar-trigger]");
    if (trigger) {
      trigger.classList.add("bg-primary", "text-primary-foreground");
      trigger.classList.remove("hover:bg-accent");
    }
    this._activeMenu = menu;
  },

  _closeAll() {
    this.el.querySelectorAll("[data-menubar-dropdown]").forEach((d) => d.classList.add("u-hidden"));
    this.el.querySelectorAll("[data-menubar-trigger]").forEach((t) => {
      t.classList.remove("bg-primary", "text-primary-foreground");
      if (t.dataset.disabled !== "true") {
        t.classList.add("hover:bg-accent");
      }
    });
    this._activeMenu = null;
  },
};

export default MenuBarHook;
