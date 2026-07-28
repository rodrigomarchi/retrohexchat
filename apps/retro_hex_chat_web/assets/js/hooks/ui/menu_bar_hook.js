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
      true,
    );

    // Click on a dropdown item closes all menus
    this.el.addEventListener("click", (e) => {
      const mobileCategory = e.target.closest("[data-mobile-menu-category]");

      if (mobileCategory) {
        e.preventDefault();
        e.stopPropagation();
        this._activateMobileMenuCategory(mobileCategory);
        return;
      }

      const copyItem = e.target.closest("[data-menubar-copy-selection]");

      if (copyItem) {
        e.preventDefault();
        e.stopPropagation();

        if (copyItem.dataset.copyDisabled === "true") {
          return;
        }

        this._copyCurrentSelection();
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
    this._refreshCopySelectionItems(menu);
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
  },

  _refreshCopySelectionItems(menu) {
    const hasSelection = this._selectedChatLogText() !== "";

    menu.querySelectorAll("[data-menubar-copy-selection]").forEach((item) => {
      item.dataset.copyDisabled = hasSelection ? "false" : "true";
      item.setAttribute("aria-disabled", hasSelection ? "false" : "true");
      item.classList.toggle("menubar-copy-disabled", !hasSelection);
    });
  },

  _selectedChatLogText() {
    if (typeof window.getSelection !== "function") return "";

    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0) return "";

    const text = selection.toString();
    if (text.trim() === "") return "";

    const chatLog = document.getElementById("chat-messages");
    if (!chatLog) return "";

    try {
      const range = selection.getRangeAt(0);
      return this._nodeInsideChatLog(range.commonAncestorContainer, chatLog) ? text : "";
    } catch {
      return "";
    }
  },

  _nodeInsideChatLog(node, chatLog) {
    if (!node) return false;

    const element = node.nodeType === 1 ? node : node.parentElement;
    return Boolean(element && chatLog.contains(element));
  },

  _copyCurrentSelection() {
    const text = this._selectedChatLogText();
    if (!text) return;

    if (navigator.clipboard && typeof navigator.clipboard.writeText === "function") {
      navigator.clipboard.writeText(text).catch(() => this._copySelectionFallback());
      return;
    }

    this._copySelectionFallback();
  },

  _copySelectionFallback() {
    if (typeof document.execCommand === "function") {
      document.execCommand("copy");
    }
  },
};

export default MenuBarHook;
