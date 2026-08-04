/**
 * LiveView binding for the menu bar.
 *
 * All behaviour lives in `lib/ui/menu_bar.js`, which knows nothing about
 * LiveView — see that module for the `data-menubar-*` / `data-mobile-menu-*`
 * contract. The landing pages run the very same engine without a LiveSocket,
 * which is why none of it lives here.
 *
 * Mounted on the `<nav role="menubar">` rendered by `Components.UI.MenuBar`.
 */
import { createMenuBar } from "../../lib/ui/menu_bar";

const MenuBarHook = {
  mounted() {
    this.menuBar = createMenuBar(this.el);
    this.menuBar.mount();
  },

  destroyed() {
    this.menuBar.destroy();
  },
};

export default MenuBarHook;
