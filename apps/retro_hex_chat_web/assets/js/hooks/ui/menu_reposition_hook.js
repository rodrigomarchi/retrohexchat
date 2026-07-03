/**
 * LiveView hook that keeps a context menu inside the viewport.
 *
 * Context menus are placed at raw cursor coordinates via inline left/top.
 * Near the right or bottom edge of the screen (e.g. the nicklist on the far
 * right) that overflows off-screen. On mount and on every server patch this
 * flips the menu left/up so it stays fully visible.
 */
import { repositionMenu } from "../../lib/ui/menu.js";

const MenuRepositionHook = {
  mounted() {
    repositionMenu(this.el);
  },

  updated() {
    repositionMenu(this.el);
  },
};

export default MenuRepositionHook;
