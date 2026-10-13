/**
 * The character creator's preview: the character being made, walking in place
 * on a little stage, turned with the two keys under it.
 *
 * It draws with the same compositor the space draws with, so what the creator
 * shows is exactly what everybody will see. The LiveView owns the recipe and
 * re-renders `data-recipe`; this controller only draws it. A person who asked
 * for less motion gets the character standing still.
 *
 * @module space/creator_preview
 */
import { log } from "../logger.js";

// The stage is the frame box shown at this integer scale: pixel art is drawn
// at whole multiples or not at all.
const SCALE = 2;
const WALK_MS = 120;

/**
 * @param {HTMLElement} el the preview element (`data-recipe`, `data-character-catalog`)
 * @param {object} deps
 * @param {(url: string) => Promise<object>} deps.load resolves a compositor
 * @param {(cb: Function) => number} [deps.requestFrame]
 * @param {(id: number) => void} [deps.cancelFrame]
 * @param {() => boolean} [deps.reducedMotion]
 */
export function createCreatorPreview(el, deps) {
  const requestFrame = deps.requestFrame ?? ((cb) => window.requestAnimationFrame(cb));
  const cancelFrame = deps.cancelFrame ?? ((id) => window.cancelAnimationFrame(id));
  const reducedMotion =
    deps.reducedMotion ??
    (() => window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches ?? false);
  const canvas = el.querySelector("[data-creator-canvas]");
  let compositor = null;
  let recipe = el.dataset.recipe;
  let dir = 0;
  let raf = null;
  let stopped = false;

  function draw(now) {
    raf = null;
    if (stopped || !compositor || !canvas) return;
    const dirs = compositor.catalog.dirs;
    const still = reducedMotion();
    const anim = still ? "idle" : "walk";
    const strip = compositor.strip(recipe, anim, dirs[dir]);
    const { w, h } = compositor.frameSize;
    const ctx = canvas.getContext("2d");
    if (ctx && strip) {
      const frames = compositor.frames(anim);
      const i = still ? 0 : Math.floor(now / WALK_MS) % frames;
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(strip, i * w, 0, w, h, 0, 0, w * SCALE, h * SCALE);
    }
    if (!still || !strip) raf = requestFrame(draw);
  }

  function schedule() {
    if (raf === null && !stopped) raf = requestFrame(draw);
  }

  function onClick(event) {
    const key = event.target.closest?.("[data-creator-turn]");
    if (!key || !compositor) return;
    const n = compositor.catalog.dirs.length;
    dir = (dir + Number(key.dataset.creatorTurn) + n) % n;
    schedule();
  }

  el.addEventListener("click", onClick);
  deps
    .load(el.dataset.characterCatalog)
    .then((loaded) => {
      // Closed while the catalog was on its way: nothing left to draw into.
      if (stopped) return;
      compositor = loaded;
      const { w, h } = compositor.frameSize;
      if (canvas) {
        canvas.width = w * SCALE;
        canvas.height = h * SCALE;
      }
      compositor.prepareAll(recipe, ["walk"]);
      schedule();
    })
    .catch((error) => log.error("[space] creator preview could not load", error));

  return {
    /** The LiveView re-rendered: draw the recipe it now holds. */
    update() {
      if (el.dataset.recipe === recipe) return;
      recipe = el.dataset.recipe;
      compositor?.prepareAll(recipe, ["walk"]);
      schedule();
    },
    /** Which way the character faces now, as the catalog names it. */
    get facing() {
      return compositor?.catalog.dirs[dir] ?? null;
    },
    destroy() {
      stopped = true;
      if (raf !== null) cancelFrame(raf);
      el.removeEventListener("click", onClick);
    },
  };
}
