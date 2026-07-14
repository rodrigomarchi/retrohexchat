/**
 * Preserve a scroll container's position across LiveView patches.
 *
 * Use this on a stable child when the scrollable element is owned by a parent
 * component. By default the hook preserves its parent element.
 */
const PreserveScrollHook = {
  mounted() {
    this.savedScroll = null;
  },

  beforeUpdate() {
    const target = this.scrollTarget();
    if (!target) return;

    this.savedScroll = {
      left: target.scrollLeft,
      top: target.scrollTop,
    };
  },

  updated() {
    const target = this.scrollTarget();
    if (!target || !this.savedScroll) return;

    target.scrollLeft = this.savedScroll.left;
    target.scrollTop = this.savedScroll.top;
  },

  scrollTarget() {
    const target = this.el.dataset.preserveScrollTarget || "parent";

    if (target === "self") return this.el;
    if (target === "parent") return this.el.parentElement;

    return document.querySelector(target);
  },
};

export default PreserveScrollHook;
