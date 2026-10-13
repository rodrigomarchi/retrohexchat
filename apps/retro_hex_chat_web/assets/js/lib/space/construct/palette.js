/**
 * The build palette's DOM: the Build key and the drawer it opens (tabs that
 * show one group of kinds at a time, one key per kind with its sprite drawn
 * into a small canvas, the status line), and the card that shows what is in
 * hand — the kind armed, the floor armed, or the piece picked — with turn,
 * remove and drop.
 *
 * Owns no build decision. It reports presses through its ports and shows the
 * build mode's state: the armed kind sunk (`data-selected="true"`), turn
 * enabled while a kind is armed or a piece is picked, remove while a piece is
 * picked. The drawer's own state is the one thing it keeps: open or shut
 * (`data-open` on the root), remembered by this browser. On a phone the
 * drawer is a sheet over the floor, so choosing a kind shuts it — the floor is
 * where the next tap goes, and the card says what that tap will build.
 *
 * A refusal is said over the room, outside the drawer, from the
 * server-translated sentences on the palette root (`data-refused-<reason>`),
 * and it goes on the next accepted edit or let-go.
 * @module space/construct/palette
 */
import { log } from "../../logger.js";

const THUMB_PADDING = 2;
const DRAWER_KEY = "rhc:space:construct-drawer";
// The width under which the drawer is a sheet over the floor (space-ui.css).
const SHEET_QUERY = "(max-width: 480px)";

/**
 * @param {HTMLElement} root - the `[data-construct-palette]` element
 * @param {{onChoose: (kind: string) => void, onPaint?: (material: string) => void,
 *   onRotate: () => void, onRemove: () => void, onDrop?: () => void,
 *   storage?: () => Storage, isSheet?: () => boolean,
 *   dirsOf?: (kind: string) => string[]|undefined}} ports
 */
export function createBuildPalette(
  root,
  {
    onChoose,
    onPaint,
    onRotate,
    onRemove,
    onDrop,
    storage = () => window.localStorage,
    isSheet = () => window.matchMedia?.(SHEET_QUERY)?.matches === true,
    dirsOf = () => undefined,
  },
) {
  const kindButtons = () => [...root.querySelectorAll("[data-construct-kind]")];
  const materialButtons = () => [...root.querySelectorAll("[data-construct-material]")];
  const one = (selector) => root.querySelector(selector);
  const status = () => one("[data-construct-status]");
  const hintLine = () => one("[data-construct-hint]");
  let sprites = { kind: () => null, tile: () => null };
  // Until the floor is pressed, a coarse pointer (a finger) is the best guess.
  let pointer = window.matchMedia?.("(pointer: coarse)")?.matches ? "touch" : "mouse";
  let shownHolding = null;

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

  const isOpen = () => root.dataset.open === "true";

  const setOpen = (open, { remember = true } = {}) => {
    root.dataset.open = open ? "true" : "false";
    one("[data-construct-toggle]")?.setAttribute("aria-expanded", open ? "true" : "false");
    if (!remember) return;
    try {
      storage().setItem(DRAWER_KEY, open ? "open" : "shut");
    } catch (error) {
      log.debug("[construct] could not remember the build drawer", error);
    }
  };

  const remembered = () => {
    try {
      return storage().getItem(DRAWER_KEY) === "open";
    } catch (error) {
      log.debug("[construct] could not read the build drawer", error);
      return false;
    }
  };

  // A sheet over the floor gets out of the way once a kind or a floor is
  // chosen; a side panel on a desktop stays for the next one.
  const chosen = () => {
    if (isSheet()) setOpen(false);
  };

  // A press must not take the keyboard from the map: Delete and R act on the
  // canvas, and a focused button would swallow them.
  const keepFocus = (event) => event.preventDefault();
  const onClick = (event) => {
    const button = event.target.closest?.("button");
    if (!button || !root.contains(button) || button.disabled) return;
    const data = button.dataset;
    if (data.constructTab) showTab(data.constructTab);
    else if (data.constructKind) {
      onChoose(data.constructKind);
      chosen();
    } else if (data.constructMaterial) {
      onPaint?.(data.constructMaterial);
      chosen();
    } else if (button.hasAttribute("data-construct-toggle")) setOpen(!isOpen());
    else if (button.hasAttribute("data-construct-close")) setOpen(false);
    else if (button.hasAttribute("data-construct-rotate")) onRotate();
    else if (button.hasAttribute("data-construct-remove")) onRemove();
    else if (button.hasAttribute("data-construct-drop")) onDrop?.();
  };

  // The key a kind or a material is chosen with.
  const keyOf = (held) =>
    held.kind
      ? kindButtons().find((b) => b.dataset.constructKind === held.kind)
      : materialButtons().find((b) => b.dataset.constructMaterial === held.material);

  // The name a kind or a material goes by: the label on its own key.
  const nameOf = (held) =>
    keyOf(held)?.getAttribute("aria-label") ?? held.kind ?? held.material ?? "";

  const renderHolding = (held) => {
    const card = one("[data-construct-holding]");
    if (!card) return;
    card.hidden = !held;
    if (!held) {
      shownHolding = null;
      return;
    }
    const id = held.kind ? `kind:${held.kind}:${held.dir}` : `floor:${held.material}`;
    if (id === shownHolding) return;
    shownHolding = id;
    const name = nameOf(held);
    card.setAttribute("aria-label", name);
    const label = card.querySelector("[data-construct-holding-name]");
    if (label) label.textContent = name;
    const tile = held.material ? keyOf(held)?.dataset.constructTile : null;
    const sprite = held.kind ? sprites.kind(held.kind, held.dir) : sprites.tile(tile);
    drawFit(card.querySelector("canvas[data-construct-holding-thumb]"), sprite);
  };

  return {
    attach() {
      root.addEventListener("mousedown", keepFocus);
      root.addEventListener("click", onClick);
      setOpen(remembered(), { remember: false });
      const line = hintLine();
      if (line && pointer === "touch" && line.dataset.touchHint) {
        line.textContent = line.dataset.touchHint;
      }
    },

    detach() {
      root.removeEventListener("mousedown", keepFocus);
      root.removeEventListener("click", onClick);
    },

    /** Open or shut the drawer (the Build key, and B). */
    toggle() {
      setOpen(!isOpen());
    },

    /** Whether the drawer is open. */
    isOpen,

    /**
     * The kind of pointer that last pressed the floor: a touch screen gets the
     * hint that has no right-click in it.
     * @param {string} type - a PointerEvent `pointerType`
     */
    usePointer(type) {
      pointer = type === "touch" || type === "pen" ? "touch" : "mouse";
    },

    /**
     * @param {{mode: string, kind?: string, material?: string}} state
     * @param {{kind?: string, dir?: string, material?: string}|null} [held] -
     *   what is in hand, resolved to a kind and facing for a picked piece
     */
    render(state, held = null) {
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
      // The card offers what applies to what is in hand: a kind to place turns
      // and drops, a floor only drops, a picked piece turns, goes or drops.
      const rotate = one("[data-construct-rotate]");
      if (rotate) {
        rotate.hidden = state.mode === "painting";
        // A kind with one facing has nothing to turn to.
        const facings = held?.kind ? dirsOf(held.kind) : undefined;
        const turns = !Array.isArray(facings) || facings.length > 1;
        rotate.disabled = !(turns && (state.mode === "placing" || state.mode === "selected"));
      }
      const remove = one("[data-construct-remove]");
      if (remove) {
        remove.hidden = state.mode === "placing" || state.mode === "painting";
        remove.disabled = state.mode !== "selected";
      }
      renderHolding(held);
      // The hint says what a press on the floor does now: paint, or build —
      // in the words of the pointer that presses it.
      const line = hintLine();
      if (line) {
        const build = pointer === "touch" ? line.dataset.touchHint : line.dataset.hint;
        const hint = state.mode === "painting" ? line.dataset.paintHint : build;
        if (hint && line.textContent !== hint) line.textContent = hint;
      }
    },

    /**
     * Draw each material's floor diamond into its key, and keep the lookups
     * the card draws what is in hand with.
     * @param {{kind: (kind: string, dir: string) => object|null, tile: (tile: string) => object|null}} lookup
     */
    drawSprites(lookup) {
      sprites = lookup;
      shownHolding = null;
      for (const button of materialButtons()) {
        drawFit(
          button.querySelector("canvas[data-construct-thumb]"),
          lookup.tile(button.dataset.constructTile),
          { centred: true },
        );
      }
      for (const button of kindButtons()) {
        drawFit(
          button.querySelector("canvas[data-construct-thumb]"),
          lookup.kind(button.dataset.constructKind, "down"),
        );
      }
    },

    /** Open the tab of one group of kinds. */
    showTab,

    /** The sentence that says why an edit was refused. */
    sentence,

    /** Say why an edit was refused, over the room. */
    refuse(reason) {
      const line = status();
      if (!line) return;
      line.textContent = sentence(reason);
      line.dataset.refused = "true";
      line.hidden = false;
    },

    /** Take the refusal down after an edit that went through, or a let-go. */
    clear() {
      const line = status();
      if (!line || line.dataset.refused !== "true") return;
      line.dataset.refused = "false";
      line.hidden = true;
      line.textContent = "";
    },
  };
}

/**
 * Draw a sprite into a key's canvas, scaled down (never up) to fit: a piece
 * stands on the canvas's bottom edge, a floor diamond sits in its middle. A
 * mirrored sprite draws mirrored.
 */
function drawFit(canvas, sprite, { centred = false } = {}) {
  const ctx = canvas?.getContext?.("2d");
  if (!ctx) return;
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (!sprite?.img) return;
  const room = Math.min(canvas.width, canvas.height) - THUMB_PADDING * 2;
  const fit = Math.min(1, room / Math.max(sprite.sw, sprite.sh));
  const w = Math.round(sprite.sw * fit);
  const h = Math.round(sprite.sh * fit);
  const dx = Math.round((canvas.width - w) / 2);
  const dy = centred ? Math.round((canvas.height - h) / 2) : canvas.height - THUMB_PADDING - h;
  if (!sprite.flipX) {
    ctx.drawImage(sprite.img, sprite.sx, sprite.sy, sprite.sw, sprite.sh, dx, dy, w, h);
    return;
  }
  ctx.save();
  ctx.translate(canvas.width, 0);
  ctx.scale(-1, 1);
  ctx.drawImage(sprite.img, sprite.sx, sprite.sy, sprite.sw, sprite.sh, dx, dy, w, h);
  ctx.restore();
}
