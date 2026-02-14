/**
 * LiveView hook for context menu keyboard navigation and viewport repositioning.
 *
 * - Repositions menu if it overflows viewport (flip up/left)
 * - Handles ArrowUp/ArrowDown/Enter/Escape for keyboard navigation
 * - Manages .focused class on menu items
 */
import { repositionMenu, createMenuNavigator } from "../lib/menu.js";

const ContextMenuHook = {
  mounted() {
    this.menuEl = this.el;
    this.items = [];

    this.collectItems();

    this.navigator = createMenuNavigator(() => this.items);

    repositionMenu(this.menuEl);
    this.setupKeyboard();
  },

  updated() {
    repositionMenu(this.menuEl);
    this.collectItems();
    this.navigator.reset();
  },

  destroyed() {
    this.removeKeyboard();
  },

  collectItems() {
    this.items = Array.from(this.menuEl.querySelectorAll("li:not(.separator):not(.disabled)"));
  },

  setupKeyboard() {
    this._onKeyDown = (e) => this.handleKeyDown(e);
    document.addEventListener("keydown", this._onKeyDown);
  },

  removeKeyboard() {
    if (this._onKeyDown) {
      document.removeEventListener("keydown", this._onKeyDown);
      this._onKeyDown = null;
    }
  },

  handleKeyDown(e) {
    if (!this.items.length) return;

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        this.navigator.moveFocus(1);
        this.focusedIndex = this.navigator.focusedIndex;
        break;
      case "ArrowUp":
        e.preventDefault();
        this.navigator.moveFocus(-1);
        this.focusedIndex = this.navigator.focusedIndex;
        break;
      case "Enter":
        e.preventDefault();
        this.navigator.selectFocused();
        break;
      case "Escape":
        e.preventDefault();
        this.closeMenu();
        break;
    }
  },

  closeMenu() {
    this.pushEvent("close_chat_context_menu", {});
    this.pushEvent("close_treebar_context_menu", {});
  },
};

export default ContextMenuHook;
