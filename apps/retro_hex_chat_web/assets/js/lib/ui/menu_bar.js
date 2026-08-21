/**
 * macOS-style menu bar — the engine, free of any framework.
 *
 * Owns every menu interaction: opening and hot-tracking the top-level
 * dropdowns, the flyout submenus, and the mobile rail that drives a single
 * shared drawer. It reads the DOM the server already rendered and decorates it,
 * which is what lets the same bar run on a public page with no LiveSocket at
 * all — the markup stands on its own and this is pure enhancement.
 *
 * Create one with `createMenuBar(el)` and drive it through `mount()` and
 * `destroy()`. The DOM contract (see `Components.UI.MenuBar`):
 *
 *   - `[data-menubar-trigger]`         opens the sibling dropdown under one wrapper
 *   - `[data-menubar-dropdown]`        the panel a trigger opens
 *   - `[data-menubar-submenu]`         a nested row, with its own panel
 *   - `[data-menubar-submenu-panel]`   that row's flyout — deliberately NOT a
 *                                      dropdown, so the parent sweep leaves it be
 *   - `[data-mobile-menu-open=<id>]`   rail button selecting a drawer section
 *   - `[data-mobile-menu-root]`        the drawer shell
 *   - `[data-mobile-menu-category=<id>]` section tab inside the drawer
 *   - `[data-mobile-menu-section=<id>]`  section panel inside the drawer
 *
 * Copy-selection items (`[data-menubar-copy-selection]`) are driven by
 * `copy_selection.js`, shared with the Start menu, which offers the same entry.
 *
 * Menus open on mousedown with preventDefault() so the composer — and the phone
 * keyboard with it — never loses focus to a menu.
 */
import { handleCopySelectionClick, refreshCopySelectionItems } from "./copy_selection";

const MenuBarCore = {
  mount() {
    this._activeMenu = null;
    this._mobileSection = null;

    this._onMouseDown = (e) => this._handleMouseDown(e);
    this._onMouseEnter = (e) => this._handleMouseEnter(e);
    this._onClick = (e) => this._handleClick(e);
    this._onOutside = (e) => {
      if (!this.el.contains(e.target)) this._closeAll();
    };
    this._onEscape = (e) => {
      if (e.key === "Escape") this._closeAll();
    };
    this._onForceClose = () => this._closeAll();

    this.el.addEventListener("mousedown", this._onMouseDown);
    this.el.addEventListener("mouseenter", this._onMouseEnter, true);
    this.el.addEventListener("click", this._onClick);
    this.el.addEventListener("menubar:close-all", this._onForceClose);
    document.addEventListener("mousedown", this._onOutside);
    document.addEventListener("keydown", this._onEscape);
  },

  destroy() {
    this.el.removeEventListener("mousedown", this._onMouseDown);
    this.el.removeEventListener("mouseenter", this._onMouseEnter, true);
    this.el.removeEventListener("click", this._onClick);
    this.el.removeEventListener("menubar:close-all", this._onForceClose);
    document.removeEventListener("mousedown", this._onOutside);
    document.removeEventListener("keydown", this._onEscape);
  },

  _handleMouseDown(e) {
    // The rail opens on mousedown like every other trigger, so the same
    // preventDefault keeps the focus (and the phone keyboard) on the composer.
    const railButton = e.target.closest("[data-mobile-menu-open]");
    if (railButton) {
      e.preventDefault();
      this._openMobileSection(railButton.dataset.mobileMenuOpen);
      return;
    }

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
  },

  // Hot tracking: hover switches menus when one is already open.
  _handleMouseEnter(e) {
    if (!this._activeMenu) return;

    // Inside an open dropdown, hovering a row drives the submenus rather
    // than the top-level menus.
    const row = e.target.closest?.("[data-menubar-dropdown] li");
    if (row) {
      this._trackSubmenuHover(row);
      return;
    }

    const trigger = e.target.closest("[data-menubar-trigger]");
    if (!trigger || trigger.dataset.disabled === "true") return;
    const menu = trigger.parentElement;
    if (menu !== this._activeMenu) this._openMenu(menu);
  },

  _handleClick(e) {
    const mobileCategory = e.target.closest("[data-mobile-menu-category]");

    if (mobileCategory) {
      e.preventDefault();
      e.stopPropagation();
      this._activateMobileMenuCategory(mobileCategory);
      return;
    }

    if (handleCopySelectionClick(e)) {
      this._closeAll();
      return;
    }

    // A submenu row is an <li> inside a dropdown, so it would otherwise hit
    // the close-everything branch below. Toggle it instead.
    const submenuTrigger = e.target.closest("[data-menubar-submenu-trigger]");

    if (submenuTrigger) {
      e.preventDefault();
      e.stopPropagation();

      const submenu = submenuTrigger.closest("[data-menubar-submenu]");

      if (submenu) {
        // A pointer hovers a row on its way to clicking it, so by the time
        // the click lands the hover has already opened the flyout. Toggling
        // on every click therefore closed it again, which put the submenu out
        // of reach of a mouse entirely. Only a click on a submenu that a
        // previous *click* opened counts as "put it away".
        const openedByClick =
          submenu.dataset.submenuOpen === "true" && submenu.dataset.submenuVia === "click";

        if (openedByClick) {
          this._setSubmenu(submenu, false);
        } else {
          this._openSubmenu(submenu, "click");
        }
      }

      return;
    }

    if (e.target.closest("[data-menubar-dropdown] li")) this._closeAll();
  },

  _openMenu(menu) {
    this._closeAll();
    const dropdown = menu.querySelector("[data-menubar-dropdown]");
    if (!dropdown) return;
    refreshCopySelectionItems(menu);
    dropdown.classList.remove("u-hidden");
    const trigger = menu.querySelector("[data-menubar-trigger]");
    if (trigger) {
      trigger.classList.add("bg-primary", "text-primary-foreground");
      trigger.classList.remove("hover:bg-accent");
    }
    this._activeMenu = menu;
  },

  // Opens the shared mobile dropdown already showing `section`. The rail has no
  // dropdown of its own: every button drives the one panel the mobile menu
  // renders, which is why the same button closes it and a different one only
  // swaps the section under an already-open drawer.
  _openMobileSection(section) {
    const root = this.el.querySelector("[data-mobile-menu-root]");
    if (!root) return;

    const menu = root.closest("[data-menubar-dropdown]")?.parentElement;
    if (!menu) return;

    if (this._activeMenu === menu && this._mobileSection === section) {
      this._closeAll();
      return;
    }

    if (this._activeMenu !== menu) this._openMenu(menu);

    const category = root.querySelector(`[data-mobile-menu-category="${section}"]`);
    if (category) this._activateMobileMenuCategory(category);
  },

  // Mirrors the open section onto the rail, so the button reads as pressed the
  // way an open menu's trigger does on the desktop. `null` clears every button.
  _syncMobileRail(section) {
    this.el.querySelectorAll("[data-mobile-menu-open]").forEach((button) => {
      const active = button.dataset.mobileMenuOpen === section;
      button.dataset.active = active ? "true" : "false";
      button.setAttribute("aria-expanded", active ? "true" : "false");
    });
  },

  _closeAll() {
    this._mobileSection = null;
    this._syncMobileRail(null);
    this.el.querySelectorAll("[data-menubar-dropdown]").forEach((d) => d.classList.add("u-hidden"));
    this.el
      .querySelectorAll("[data-menubar-submenu]")
      .forEach((submenu) => this._setSubmenu(submenu, false));
    this.el.querySelectorAll("[data-menubar-trigger]").forEach((t) => {
      t.classList.remove("bg-primary", "text-primary-foreground");
      if (t.dataset.disabled !== "true") {
        t.classList.add("hover:bg-accent");
      }
    });
    this._activeMenu = null;
  },

  // Hovering a submenu row opens it; hovering any sibling row closes the
  // submenus of that dropdown, so at most one flyout is ever showing.
  _trackSubmenuHover(row) {
    const submenu = row.closest("[data-menubar-submenu]");

    if (submenu) {
      this._openSubmenu(submenu);
      return;
    }

    const dropdown = row.closest("[data-menubar-dropdown]");
    if (dropdown) this._closeSiblingSubmenus(dropdown, null);
  },

  _openSubmenu(submenu, via = "hover") {
    const dropdown = submenu.closest("[data-menubar-dropdown]");
    if (dropdown) this._closeSiblingSubmenus(dropdown, submenu);

    // Hovering inside an already-clicked submenu must not downgrade it back to
    // "hover", or the click that put it away would open it instead.
    const alreadyClicked =
      submenu.dataset.submenuOpen === "true" && submenu.dataset.submenuVia === "click";

    this._setSubmenu(submenu, true, alreadyClicked ? "click" : via);
  },

  _closeSiblingSubmenus(dropdown, except) {
    dropdown.querySelectorAll("[data-menubar-submenu]").forEach((submenu) => {
      if (submenu !== except) this._setSubmenu(submenu, false);
    });
  },

  // `via` records what opened the flyout — a hover or a deliberate click — so
  // the click handler can tell "the pointer just arrived here" from "the reader
  // is clicking this a second time to put it away".
  _setSubmenu(submenu, open, via = "hover") {
    submenu.dataset.submenuOpen = open ? "true" : "false";

    if (open) {
      submenu.dataset.submenuVia = via;
    } else {
      delete submenu.dataset.submenuVia;
    }

    const panel = submenu.querySelector("[data-menubar-submenu-panel]");
    if (panel) panel.classList.toggle("u-hidden", !open);
  },

  _activateMobileMenuCategory(category) {
    const root = category.closest("[data-mobile-menu-root]");
    if (!root) return;

    const section = category.dataset.mobileMenuCategory;
    root.querySelectorAll("[data-mobile-menu-category]").forEach((button) => {
      const active = button.dataset.mobileMenuCategory === section;
      button.dataset.active = active ? "true" : "false";
      button.setAttribute("aria-selected", active ? "true" : "false");
    });
    root.querySelectorAll("[data-mobile-menu-section]").forEach((panel) => {
      panel.classList.toggle("u-hidden", panel.dataset.mobileMenuSection !== section);
    });

    // The category column inside the drawer switches sections too, so the rail
    // learns the section from here rather than from the tap that opened it.
    this._mobileSection = section;
    this._syncMobileRail(section);
  },
};

/** Builds a menu bar over `el` (a `<nav role="menubar">`). */
export function createMenuBar(el) {
  const bar = Object.create(MenuBarCore);
  bar.el = el;
  return bar;
}

export default MenuBarCore;
