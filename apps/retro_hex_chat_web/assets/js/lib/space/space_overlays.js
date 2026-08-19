/**
 * DOM overlays for the virtual-space canvas: the connecting/loading indicator
 * and the board modal drawn from the sprite atlas.
 *
 * Owns the overlay DOM and the one-way "loading hidden" latch — once the first
 * frame after asset load hides the panel it stays hidden, so a late status
 * update cannot flash it back. Knows nothing about the channel, the engine or
 * LiveView; the board is drawn through the injected `board` port so the atlas
 * stays the hook's to own.
 */

/**
 * @param {HTMLElement} el - the space shell element
 * @param {{board?: (asset: string) => {canvas?: HTMLCanvasElement}|null|undefined}} [ports]
 */
export function createSpaceOverlays(el, { board } = {}) {
  let loadingHidden = false;

  return {
    setLoadingText(text) {
      const host = el.querySelector("[data-space-loading]");
      if (!host || loadingHidden) return;

      const indicatorText = host.querySelector("[data-space-loading-text]");
      if (indicatorText) indicatorText.textContent = text;

      const panel = host.querySelector("[data-space-loading-panel]");
      const title = panel?.getAttribute("aria-label")?.split(":")[0];
      if (panel && title) panel.setAttribute("aria-label", `${title}: ${text}`);
    },

    hideLoading() {
      const host = el.querySelector("[data-space-loading]");
      if (!host || loadingHidden) return;
      loadingHidden = true;
      host.hidden = true;
      host.setAttribute("aria-hidden", "true");
    },

    renderModal(modal) {
      const host = el.querySelector("[data-space-modal]");
      if (!host) return;

      if (!modal) {
        host.hidden = true;
        host.replaceChildren();
        return;
      }

      host.hidden = false;
      const title = document.createElement("div");
      title.className = "font-bold";
      title.textContent = modal.title ?? "";
      const drawn = board?.(modal.asset);
      host.replaceChildren(title);
      if (drawn?.canvas) host.appendChild(drawn.canvas);
    },
  };
}
