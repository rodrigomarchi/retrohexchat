/**
 * LiveView binding for the menu bar.
 *
 * All behaviour lives in `lib/ui/menu_bar.js`, which knows nothing about
 * LiveView — see that module for the `data-menubar-*` / `data-mobile-menu-*`
 * contract. A page of the site runs the very same engine before the chat's
 * LiveSocket exists (`lib/ui/site_menu_bar.js`), which is why none of it lives
 * here.
 *
 * Mounted on the `<nav role="menubar">` rendered by `Components.UI.MenuBar`.
 */
import { createMenuBar } from "../../lib/ui/menu_bar";
import { siteMenuBarFor } from "../../lib/ui/site_menu_bar";

const MenuBarHook = {
  // A page's menu bar is already running when the chat starts (`desktop.js`):
  // adopt it rather than mounting a second engine on the same element.
  mounted() {
    this.menuBar = siteMenuBarFor(this.el);
    if (this.menuBar) {
      // Joining patched the bar before this hook existed: put back what the
      // first tap opened.
      this.menuBar.restore();
    } else {
      this.menuBar = createMenuBar(this.el);
      this.menuBar.mount();
    }
  },

  // The server renders every dropdown closed, so any patch of the bar closes
  // the menu the person is reading. Put it back.
  updated() {
    this.menuBar.restore();
  },

  destroyed() {
    this.menuBar.destroy();
  },
};

export default MenuBarHook;
