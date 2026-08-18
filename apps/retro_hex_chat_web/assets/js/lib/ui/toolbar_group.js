/**
 * Collapsible toolbar groups — the browser-side controller, no LiveView.
 *
 * Each group has a toggle ([data-toolbar-group-toggle]) that shows or hides its
 * dropdown (.toolbar-group-dropdown). mousedown with preventDefault keeps focus
 * on the chat input; clicking a button inside a dropdown, or anywhere outside,
 * or pressing Escape, closes everything.
 *
 * @module ui/toolbar_group
 */

export function createToolbarGroup(el) {
  const closeAll = () => {
    el.querySelectorAll(".toolbar-group-dropdown").forEach((d) => d.classList.add("u-hidden"));
  };

  const onMouseDown = (e) => {
    const toggle = e.target.closest("[data-toolbar-group-toggle]");
    if (!toggle) return;
    e.preventDefault();

    const group = toggle.closest(".toolbar-group");
    const dropdown = group && group.querySelector(".toolbar-group-dropdown");
    if (!dropdown) return;

    const wasHidden = dropdown.classList.contains("u-hidden");
    closeAll();
    if (wasHidden) dropdown.classList.remove("u-hidden");
  };

  const onClick = (e) => {
    if (e.target.closest(".toolbar-group-dropdown .toolbar-btn")) closeAll();
  };

  const onOutside = (e) => {
    if (!el.contains(e.target)) closeAll();
  };

  const onEscape = (e) => {
    if (e.key === "Escape") closeAll();
  };

  return {
    mount() {
      el.addEventListener("mousedown", onMouseDown);
      el.addEventListener("click", onClick);
      document.addEventListener("mousedown", onOutside);
      document.addEventListener("keydown", onEscape);
    },

    destroy() {
      el.removeEventListener("mousedown", onMouseDown);
      el.removeEventListener("click", onClick);
      document.removeEventListener("mousedown", onOutside);
      document.removeEventListener("keydown", onEscape);
    },

    closeAll,
  };
}
