/**
 * Menu navigation and repositioning logic.
 *
 * Extracted from: context_menu_hook.js
 */

/**
 * Reposition a menu element so it doesn't overflow the viewport.
 *
 * @param {HTMLElement} el
 */
export function repositionMenu(el) {
  const rect = el.getBoundingClientRect();
  const vw = window.innerWidth;
  const vh = window.innerHeight;

  // Flip left if overflows right
  if (rect.right > vw) {
    const overflow = rect.right - vw;
    const currentLeft = parseInt(el.style.left, 10) || rect.left;
    el.style.left = Math.max(0, currentLeft - overflow - 4) + "px";
  }

  // Flip up if overflows bottom
  if (rect.bottom > vh) {
    const overflow = rect.bottom - vh;
    const currentTop = parseInt(el.style.top, 10) || rect.top;
    el.style.top = Math.max(0, currentTop - overflow - 4) + "px";
  }
}

/**
 * Create a menu keyboard navigator.
 *
 * @param {Function} getItems - Returns current list of navigable items
 * @returns {Object} Navigator with moveFocus, clearFocus, selectFocused, reset
 */
export function createMenuNavigator(getItems) {
  let focusedIndex = -1;

  return {
    get focusedIndex() {
      return focusedIndex;
    },

    moveFocus(direction) {
      const items = getItems();
      if (!items.length) return;

      this.clearFocus();

      if (focusedIndex === -1 && direction === 1) {
        focusedIndex = 0;
      } else if (focusedIndex === -1 && direction === -1) {
        focusedIndex = items.length - 1;
      } else {
        focusedIndex += direction;
        if (focusedIndex < 0) focusedIndex = items.length - 1;
        if (focusedIndex >= items.length) focusedIndex = 0;
      }

      items[focusedIndex].classList.add("focused");
      items[focusedIndex].scrollIntoView({ block: "nearest" });
    },

    clearFocus() {
      const items = getItems();
      items.forEach((item) => item.classList.remove("focused"));
    },

    selectFocused() {
      const items = getItems();
      if (focusedIndex >= 0 && focusedIndex < items.length) {
        items[focusedIndex].click();
      }
    },

    reset() {
      focusedIndex = -1;
      this.clearFocus();
    },
  };
}
