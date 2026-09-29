/**
 * Keeps the keyboard inside a list whose own controls can remove themselves.
 *
 * A row's remove button leaves with the row it removes, and the browser has
 * nowhere to send focus when the focused element stops existing — it falls to
 * <body>. A reader tidying a list from the bottom loses their place on every
 * press and has to tab back through the whole dialog. This catches that fall
 * and puts focus on the list, so the next Tab resumes where they were.
 *
 * Only the fall is caught: focus that lands on something real is left alone,
 * which is why reordering with the arrow buttons is unaffected.
 */
const ActionListFocusHook = {
  mounted() {
    this._onFocusOut = () => {
      requestAnimationFrame(() => {
        if (document.activeElement !== document.body) return;
        if (!this.el.isConnected) return;
        this.el.focus();
      });
    };

    this.el.addEventListener("focusout", this._onFocusOut);
  },

  destroyed() {
    this.el.removeEventListener("focusout", this._onFocusOut);
  },
};

export default ActionListFocusHook;
