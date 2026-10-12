/**
 * The build palette's DOM: the tabs that show one group of kinds at a time,
 * one key per kind (its sprite drawn into a small canvas from the atlas), the
 * turn and remove keys, and the status line.
 *
 * Owns no decision. It reports presses through its ports and shows the build
 * mode's state: the armed kind sunk (`data-selected="true"`), turn enabled
 * while a kind is armed or a piece is picked, remove while a piece is picked.
 * A refusal is said in the status line from the server-translated sentences on
 * the palette root (`data-refused-<reason>`), and the hint comes back on the
 * next accepted edit.
 * @module space/construct/palette
 */

const THUMB_PADDING = 2;

/**
 * @param {HTMLElement} root - the `[data-construct-palette]` element
 * @param {{onChoose: (kind: string) => void, onPaint?: (material: string) => void, onRotate: () => void, onRemove: () => void}} ports
 */
export function createBuildPalette(root, { onChoose, onPaint, onRotate, onRemove }) {
  const kindButtons = () => [...root.querySelectorAll("[data-construct-kind]")];
  const materialButtons = () => [...root.querySelectorAll("[data-construct-material]")];
  const rotateButton = () => root.querySelector("[data-construct-rotate]");
  const removeButton = () => root.querySelector("[data-construct-remove]");
  const status = () => root.querySelector("[data-construct-status]");

  const sentence = (reason) =>
    root.getAttribute(`data-refused-${reason}`) ?? root.dataset.refusedDefault ?? "";

  const showTab = (group) => {
    for (const tab of root.querySelectorAll("[data-construct-tab]")) {
      const open = tab.dataset.constructTab === group;
      tab.dataset.selected = open ? "true" : "false";
      tab.setAttribute("aria-selected", open ? "true" : "false");
    }
    for (const panel of root.querySelectorAll("[data-construct-group]")) {
      panel.hidden = panel.dataset.constructGroup !== group;
    }
  };

  // A press must not take the keyboard from the map: Delete and R act on the
  // canvas, and a focused button would swallow them.
  const keepFocus = (event) => event.preventDefault();
  const onClick = (event) => {
    const button = event.target.closest?.("button");
    if (!button || !root.contains(button) || button.disabled) return;
    if (button.dataset.constructTab) showTab(button.dataset.constructTab);
    else if (button.dataset.constructKind) onChoose(button.dataset.constructKind);
    else if (button.dataset.constructMaterial) onPaint?.(button.dataset.constructMaterial);
    else if (button.hasAttribute("data-construct-rotate")) onRotate();
    else if (button.hasAttribute("data-construct-remove")) onRemove();
  };

  return {
    attach() {
      root.addEventListener("mousedown", keepFocus);
      root.addEventListener("click", onClick);
    },

    detach() {
      root.removeEventListener("mousedown", keepFocus);
      root.removeEventListener("click", onClick);
    },

    /** @param {{mode: string, kind?: string, material?: string}} state */
    render(state) {
      const press = (button, armed) => {
        button.dataset.selected = armed ? "true" : "false";
        button.setAttribute("aria-pressed", armed ? "true" : "false");
      };
      for (const button of kindButtons()) {
        press(button, state.mode === "placing" && state.kind === button.dataset.constructKind);
      }
      for (const button of materialButtons()) {
        press(
          button,
          state.mode === "painting" && state.material === button.dataset.constructMaterial,
        );
      }
      const rotate = rotateButton();
      if (rotate) rotate.disabled = !(state.mode === "placing" || state.mode === "selected");
      const remove = removeButton();
      if (remove) remove.disabled = state.mode !== "selected";
      // The hint says what a press on the floor does now: paint, or build.
      const line = status();
      if (line && line.dataset.refused !== "true") {
        const hint = state.mode === "painting" ? line.dataset.paintHint : line.dataset.hint;
        if (hint && line.textContent !== hint) line.textContent = hint;
      }
    },

    /**
     * Draw each material's floor diamond into its key.
     * @param {(tile: string) => {img: CanvasImageSource, sx:number, sy:number, sw:number, sh:number}|null} spriteFor
     */
    drawMaterials(spriteFor) {
      for (const button of materialButtons()) {
        const canvas = button.querySelector("canvas[data-construct-thumb]");
        const sprite = spriteFor(button.dataset.constructTile);
        const ctx = canvas?.getContext?.("2d");
        if (!ctx || !sprite?.img) continue;
        ctx.imageSmoothingEnabled = false;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const w = Math.min(sprite.sw, canvas.width);
        const h = Math.round((sprite.sh * w) / sprite.sw);
        const dx = Math.round((canvas.width - w) / 2);
        const dy = Math.round((canvas.height - h) / 2);
        ctx.drawImage(sprite.img, sprite.sx, sprite.sy, sprite.sw, sprite.sh, dx, dy, w, h);
      }
    },

    /**
     * Draw each kind's sprite into its key, scaled down to fit and centred.
     * @param {(kind: string) => {img: CanvasImageSource, sx:number, sy:number, sw:number, sh:number}|null} spriteFor
     */
    drawThumbnails(spriteFor) {
      for (const button of kindButtons()) {
        const canvas = button.querySelector("canvas[data-construct-thumb]");
        const sprite = spriteFor(button.dataset.constructKind);
        const ctx = canvas?.getContext?.("2d");
        if (!ctx || !sprite?.img) continue;
        ctx.imageSmoothingEnabled = false;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const room = Math.min(canvas.width, canvas.height) - THUMB_PADDING * 2;
        const fit = Math.min(1, room / Math.max(sprite.sw, sprite.sh));
        const w = Math.round(sprite.sw * fit);
        const h = Math.round(sprite.sh * fit);
        const dx = Math.round((canvas.width - w) / 2);
        const dy = canvas.height - THUMB_PADDING - h;
        if (!sprite.flipX) {
          ctx.drawImage(sprite.img, sprite.sx, sprite.sy, sprite.sw, sprite.sh, dx, dy, w, h);
          continue;
        }
        // A mirrored kind (a corner turned the other way) draws mirrored here too.
        ctx.save();
        ctx.translate(canvas.width, 0);
        ctx.scale(-1, 1);
        ctx.drawImage(sprite.img, sprite.sx, sprite.sy, sprite.sw, sprite.sh, dx, dy, w, h);
        ctx.restore();
      }
    },

    /** Open the tab of one group of kinds. */
    showTab,

    /** The sentence that says why an edit was refused. */
    sentence,

    /** Say why an edit was refused. */
    refuse(reason) {
      const line = status();
      if (!line) return;
      line.textContent = sentence(reason);
      line.dataset.refused = "true";
    },

    /** Put the hint back after an edit that went through. */
    clear() {
      const line = status();
      if (!line || line.dataset.refused !== "true") return;
      line.dataset.refused = "false";
      line.textContent = line.dataset.hint ?? "";
    },
  };
}
