/**
 * DOM overlays for the virtual-space canvas: the connecting/loading indicator,
 * the board modal drawn from the sprite atlas, and the spoken-line region that
 * says in text what the canvas draws as a bubble.
 *
 * Owns the overlay DOM and the one-way "loading hidden" latch — once the first
 * frame after asset load hides the panel it stays hidden, so a late status
 * update cannot flash it back. Knows nothing about the channel, the engine or
 * LiveView; the board is drawn through the injected `board` port so the atlas
 * stays the hook's to own, and a confirm's buttons answer through the
 * `confirm`/`cancel` ports.
 */

/**
 * @param {HTMLElement} el - the space shell element
 * @param {{board?: (asset: string) => {canvas?: HTMLCanvasElement}|null|undefined, confirm?: () => void, cancel?: () => void}} [ports]
 */
export function createSpaceOverlays(el, { board, confirm, cancel } = {}) {
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

    // A bubble is pixels on a canvas, which a screen reader cannot read. The
    // last line said is kept in a polite live region as well, in words.
    announceLine({ nickname, text } = {}) {
      const host = el.querySelector("[data-space-said]");
      if (!host || typeof text !== "string" || !text) return;
      host.textContent = nickname ? `${nickname}: ${text}` : text;
    },

    // A knockout and the getting up are canvas animations too. The sentences
    // come from the server, already translated, as templates on the region.
    announceAction({ kind, nickname } = {}) {
      const host = el.querySelector("[data-space-said]");
      if (!host || !nickname) return;
      const template =
        kind === "ko" ? host.dataset.koText : kind === "getup" ? host.dataset.getupText : null;
      if (!template) return;
      host.textContent = template.replace("%{name}", nickname);
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
      if (modal.kind === "confirm") {
        host.replaceChildren(...confirmContent(el, host, modal, { confirm, cancel }));
        host.querySelector("[data-space-modal-yes]")?.focus();
        return;
      }

      const title = document.createElement("div");
      title.className = "font-bold";
      title.textContent = modal.title ?? "";
      const drawn = board?.(modal.asset);
      host.replaceChildren(title);
      if (drawn?.canvas) host.appendChild(drawn.canvas);
    },
  };
}

// A gate's question and its two answers, cloned from the server-rendered
// template so the buttons are the app's own. The sentence is the server's too,
// keyed by the confirm's action on the modal host (`data-confirm-<action>`); a
// gate with no sentence for its action falls back to its own title.
function confirmContent(el, host, modal, { confirm, cancel }) {
  const template = el.querySelector("template[data-space-confirm-template]");
  if (!template) return [];
  const content = template.content.cloneNode(true);

  const question = content.querySelector("[data-space-modal-question]");
  if (question) {
    question.textContent = host.getAttribute(`data-confirm-${modal.action}`) ?? modal.title ?? "";
  }
  content.querySelector("[data-space-modal-yes]")?.addEventListener("click", () => confirm?.());
  content.querySelector("[data-space-modal-no]")?.addEventListener("click", () => cancel?.());
  return [...content.childNodes];
}
