/**
 * LiveView hook for context menu keyboard navigation and viewport repositioning.
 *
 * - Repositions menu if it overflows viewport (flip up/left)
 * - Handles ArrowUp/ArrowDown/Enter/Escape for keyboard navigation
 * - Manages .focused class on menu items
 */
const ContextMenuHook = {
  mounted() {
    this.menuEl = this.el;
    this.focusedIndex = -1;
    this.items = [];

    this.reposition();
    this.collectItems();
    this.setupKeyboard();
  },

  updated() {
    this.reposition();
    this.collectItems();
  },

  destroyed() {
    this.removeKeyboard();
  },

  reposition() {
    const rect = this.menuEl.getBoundingClientRect();
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    // Flip left if overflows right
    if (rect.right > vw) {
      const overflow = rect.right - vw;
      const currentLeft = parseInt(this.menuEl.style.left, 10) || rect.left;
      this.menuEl.style.left = Math.max(0, currentLeft - overflow - 4) + "px";
    }

    // Flip up if overflows bottom
    if (rect.bottom > vh) {
      const overflow = rect.bottom - vh;
      const currentTop = parseInt(this.menuEl.style.top, 10) || rect.top;
      this.menuEl.style.top = Math.max(0, currentTop - overflow - 4) + "px";
    }
  },

  collectItems() {
    // Collect non-disabled, non-separator menu items
    this.items = Array.from(
      this.menuEl.querySelectorAll("li:not(.separator):not(.disabled)")
    );
    this.focusedIndex = -1;
    this.clearFocus();
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
        this.moveFocus(1);
        break;
      case "ArrowUp":
        e.preventDefault();
        this.moveFocus(-1);
        break;
      case "Enter":
        e.preventDefault();
        this.selectFocused();
        break;
      case "Escape":
        e.preventDefault();
        this.closeMenu();
        break;
    }
  },

  moveFocus(direction) {
    this.clearFocus();

    if (this.focusedIndex === -1 && direction === 1) {
      this.focusedIndex = 0;
    } else if (this.focusedIndex === -1 && direction === -1) {
      this.focusedIndex = this.items.length - 1;
    } else {
      this.focusedIndex += direction;
      if (this.focusedIndex < 0) this.focusedIndex = this.items.length - 1;
      if (this.focusedIndex >= this.items.length) this.focusedIndex = 0;
    }

    this.items[this.focusedIndex].classList.add("focused");
    this.items[this.focusedIndex].scrollIntoView({ block: "nearest" });
  },

  clearFocus() {
    this.items.forEach((item) => item.classList.remove("focused"));
  },

  selectFocused() {
    if (this.focusedIndex >= 0 && this.focusedIndex < this.items.length) {
      this.items[this.focusedIndex].click();
    }
  },

  closeMenu() {
    // Push close event to LiveView
    this.pushEvent("close_chat_context_menu", {});
    this.pushEvent("close_treebar_context_menu", {});
  },
};

export default ContextMenuHook;
