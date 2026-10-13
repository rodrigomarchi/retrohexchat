/**
 * Compose Space characters from the creator's layered pieces.
 *
 * A character is a recipe (`character_recipe.js`); its pieces are indexed PNG
 * sheets, one per piece and clip, listed in the creator catalog. For one
 * (recipe, clip, facing) the compositor recolours each piece by rewriting its
 * palette (`png_palette.js`), decodes it, and draws the pieces in order —
 * base, face, hair, hat, the hair first cut where the hat covers it — into a
 * *strip*: the clip's frames side by side, each the catalog's frame box. The
 * renderer then blits one frame of the strip like any other sprite.
 *
 * Strips are made on demand and kept in a least-recently-used cache bounded in
 * bytes, because a room of strangers each wearing something different is many
 * strips, and most of them are only ever seen walking one way. The decoded,
 * recoloured pieces are cached the same way, keyed by piece, clip and colours,
 * so two people in the same tunic share it.
 *
 * Everything that touches the browser (fetching, decoding, canvases) is
 * passed in, so the composing plan is testable without one.
 *
 * @module space/character_compositor
 */
import { log } from "../logger.js";
import { patchPlte } from "./png_palette.js";
import { colourKey, paletteEntries, parseRecipe, planLayers } from "./character_recipe.js";

const DEFAULT_STRIP_BUDGET = 48 * 1024 * 1024;
const DEFAULT_SOURCE_BUDGET = 24 * 1024 * 1024;

/**
 * The draw operations of one frame, in order, without touching an image.
 *
 * @returns {Array<object>|null} ops: {layer, kind, colours, anim, sx, sy, sw,
 *   sh, dx, dy, mask?: {layer, sx, sy, sw, sh, dx, dy}}, all in frame-box
 *   coordinates (dx/dy relative to the frame's top-left).
 */
export function planFrame(recipe, anim, dir, frame, catalog) {
  const layers = planLayers(recipe, catalog);
  if (!layers) return null;
  const di = catalog.dirs.indexOf(dir);
  if (di < 0 || !catalog.anims[anim]) return null;
  const [bx, by] = catalog.box;
  const base = catalog.layers[layers[0].layer];
  const [ddx, ddy] = base?.delta?.[anim]?.[di]?.[frame] ?? [0, 0];
  const hat = layers.find((l) => l.kind === "hat");
  const hatLayer = hat ? catalog.layers[hat.layer] : null;
  const ops = [];
  for (const { layer, kind, colours } of layers) {
    const piece = catalog.layers[layer];
    const a = piece?.anims?.[anim];
    if (!a) return null;
    const [cw, ch] = a.cell;
    const shift = kind === "base" ? [0, 0] : [ddx, ddy];
    const op = {
      layer,
      kind,
      colours,
      anim,
      sx: frame * cw,
      sy: di * ch,
      sw: cw,
      sh: ch,
      dx: a.origin[0] - bx + shift[0],
      dy: a.origin[1] - by + shift[1],
    };
    const m = kind === "hair" ? hatLayer?.mask?.[anim] : null;
    if (m) {
      const [mw, mh] = m.cell;
      op.mask = {
        layer: hat.layer,
        sx: frame * mw,
        sy: di * mh,
        sw: mw,
        sh: mh,
        dx: m.origin[0] - bx + ddx,
        dy: m.origin[1] - by + ddy,
      };
    }
    ops.push(op);
  }
  return ops;
}

/** A least-recently-used map bounded by the summed `bytes` of its values. */
export function createLru(budget, onEvict = () => {}) {
  const entries = new Map();
  let used = 0;
  return {
    get(key) {
      if (!entries.has(key)) return undefined;
      const value = entries.get(key);
      entries.delete(key);
      entries.set(key, value);
      return value.item;
    },
    set(key, item, bytes) {
      if (entries.has(key)) {
        const old = entries.get(key);
        used -= old.bytes;
        entries.delete(key);
        if (old.item !== item) onEvict(old.item);
      }
      entries.set(key, { item, bytes });
      used += bytes;
      for (const [k, v] of entries) {
        if (used <= budget || k === key) break;
        entries.delete(k);
        used -= v.bytes;
        onEvict(v.item);
      }
    },
    get size() {
      return entries.size;
    },
    get bytes() {
      return used;
    },
  };
}

// A strip or sheet that could not be made is not asked for again on every
// frame: it waits this long before the next try.
const RETRY_MS = 10_000;

/**
 * @param {object} deps
 * @param {object} deps.catalog the creator's web catalog
 * @param {(url: string) => Promise<Uint8Array>} deps.fetchBytes
 * @param {(png: Uint8Array) => Promise<CanvasImageSource>} deps.decode
 * @param {(w: number, h: number) => HTMLCanvasElement|OffscreenCanvas} deps.makeCanvas
 * @param {() => void} [deps.onComposed] called when a strip becomes available
 * @param {() => number} [deps.now] the clock retries are timed by
 */
export function createCharacterCompositor(deps) {
  const { catalog, fetchBytes, decode, makeCanvas } = deps;
  const onComposed = typeof deps.onComposed === "function" ? deps.onComposed : () => {};
  const now = typeof deps.now === "function" ? deps.now : () => Date.now();
  const [, , bw, bh] = catalog.box;
  const strips = createLru(deps.stripBudget ?? DEFAULT_STRIP_BUDGET);
  // Decoded pieces are dropped, never closed, when the cache is full: a strip
  // being composed may still be drawing from one, and a closed bitmap throws.
  const sources = createLru(deps.sourceBudget ?? DEFAULT_SOURCE_BUDGET);
  const bytes = new Map(); // url -> Promise<Uint8Array>, the sheets as downloaded
  const decoding = new Map(); // source key -> Promise<bitmap>
  const pending = new Map(); // strip key -> Promise<canvas|null>
  const failed = new Map(); // strip key -> when it last failed

  function sheetBytes(url) {
    if (!bytes.has(url)) {
      const promise = fetchBytes(url);
      bytes.set(url, promise);
      promise.catch((error) => {
        bytes.delete(url);
        log.warn("[space] character sheet failed to load", url, error);
      });
    }
    return bytes.get(url);
  }

  // A piece's sheet for one clip, recoloured and decoded; masks are not dyed.
  // Two strips that need the same piece in the same colours share one decode.
  function source(layerName, anim, colours, { mask = false } = {}) {
    const piece = catalog.layers[layerName];
    const a = mask ? piece.mask[anim] : piece.anims[anim];
    const key = `${layerName}|${anim}|${mask ? "mask" : colourKey(piece, colours)}`;
    const cached = sources.get(key);
    if (cached) return Promise.resolve(cached);
    if (decoding.has(key)) return decoding.get(key);
    const promise = sheetBytes(a.url)
      .then((png) => {
        const entries = mask ? [] : paletteEntries(piece, colours, catalog);
        return decode(entries.length ? patchPlte(png, entries) : png);
      })
      .then((bitmap) => {
        const [cw, ch] = a.cell;
        sources.set(key, bitmap, cw * catalog.anims[anim].frames * ch * catalog.dirs.length * 4);
        return bitmap;
      })
      .finally(() => decoding.delete(key));
    decoding.set(key, promise);
    return promise;
  }

  async function compose(recipe, anim, dir) {
    const frames = catalog.anims[anim].frames;
    const plans = [];
    for (let i = 0; i < frames; i += 1) {
      const ops = planFrame(recipe, anim, dir, i, catalog);
      if (!ops) return null;
      plans.push(ops);
    }
    const images = new Map();
    for (const op of plans[0]) {
      images.set(op.layer, await source(op.layer, anim, op.colours));
      if (op.mask) {
        images.set(`${op.mask.layer}:mask`, await source(op.mask.layer, anim, {}, { mask: true }));
      }
    }
    const strip = makeCanvas(bw * frames, bh);
    const ctx = strip.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    const scratch = plans[0].some((op) => op.mask) ? makeCanvas(bw, bh) : null;
    plans.forEach((ops, i) => {
      for (const op of ops) {
        const img = images.get(op.layer);
        if (!op.mask) {
          ctx.drawImage(img, op.sx, op.sy, op.sw, op.sh, i * bw + op.dx, op.dy, op.sw, op.sh);
          continue;
        }
        // Hair under a hat: drawn alone, cut where the hat covers the head,
        // then laid on the figure.
        const s = scratch.getContext("2d");
        s.imageSmoothingEnabled = false;
        s.globalCompositeOperation = "source-over";
        s.clearRect(0, 0, bw, bh);
        s.drawImage(img, op.sx, op.sy, op.sw, op.sh, op.dx, op.dy, op.sw, op.sh);
        s.globalCompositeOperation = "destination-out";
        const m = op.mask;
        s.drawImage(images.get(`${m.layer}:mask`), m.sx, m.sy, m.sw, m.sh, m.dx, m.dy, m.sw, m.sh);
        s.globalCompositeOperation = "source-over";
        ctx.drawImage(scratch, i * bw, 0);
      }
    });
    return strip;
  }

  function stripKey(recipe, anim, dir) {
    return `${recipe}|${anim}|${dir}`;
  }

  /** Make a strip if it is not made yet; resolves to it (or null). */
  function prepare(recipe, anim, dir) {
    const key = stripKey(recipe, anim, dir);
    const ready = strips.get(key);
    if (ready) return Promise.resolve(ready);
    if (pending.has(key)) return pending.get(key);
    if (now() - (failed.get(key) ?? -Infinity) < RETRY_MS) return Promise.resolve(null);
    const promise = compose(recipe, anim, dir)
      .then((strip) => {
        if (strip) {
          failed.delete(key);
          strips.set(key, strip, bw * catalog.anims[anim].frames * bh * 4);
          onComposed();
        } else {
          failed.set(key, now());
        }
        return strip;
      })
      .catch((error) => {
        failed.set(key, now());
        log.warn("[space] character could not be composed", recipe, anim, dir, error);
        return null;
      })
      .finally(() => pending.delete(key));
    pending.set(key, promise);
    return promise;
  }

  // While the strip a pose wants is still being made, the character is drawn
  // in the nearest one already made rather than not at all: the same clip or
  // standing, facing the same way; standing facing south; anything of theirs;
  // and, for somebody nothing is made of yet, the default character standing.
  function nearest(recipe, anim, dir) {
    const tries = [
      [recipe, anim, dir],
      [recipe, "idle", dir],
      [recipe, "walk", dir],
      [recipe, "idle", catalog.dirs[0]],
    ];
    for (const [r, a, d] of tries) {
      const strip = strips.get(stripKey(r, a, d));
      if (strip) return { strip, anim: a };
    }
    for (const a of ["idle", "walk"]) {
      for (const d of catalog.dirs) {
        const strip = strips.get(stripKey(recipe, a, d));
        if (strip) return { strip, anim: a };
      }
    }
    const fallback = strips.get(stripKey(catalog.default, "idle", catalog.dirs[0]));
    if (fallback) return { strip: fallback, anim: "idle" };
    prepare(catalog.default, "idle", catalog.dirs[0]);
    return null;
  }

  return {
    catalog,
    frameSize: { w: bw, h: bh },
    valid(recipe) {
      return parseRecipe(recipe, catalog) !== null;
    },
    /** The strip for (recipe, clip, facing), or null while it is being made. */
    strip(recipe, anim, dir) {
      const ready = strips.get(stripKey(recipe, anim, dir));
      if (ready) return ready;
      prepare(recipe, anim, dir);
      return null;
    },
    /**
     * The strip for (recipe, clip, facing) if it is made, else the nearest one
     * that is (see above), as {strip, anim}; null only before anything is.
     */
    stripOrNearest(recipe, anim, dir) {
      const ready = strips.get(stripKey(recipe, anim, dir));
      if (ready) return { strip: ready, anim };
      prepare(recipe, anim, dir);
      return nearest(recipe, anim, dir);
    },
    prepare,
    /** Make every facing of the given clips; resolves when all are made. */
    prepareAll(recipe, anims) {
      const jobs = [];
      for (const anim of anims) {
        for (const dir of catalog.dirs) jobs.push(prepare(recipe, anim, dir));
      }
      return Promise.all(jobs);
    },
    /** Start downloading every piece's sheets for these clips (a failure is
     * logged by the download itself, and tried again when a strip needs it). */
    prefetch(anims) {
      for (const layer of Object.values(catalog.layers)) {
        for (const anim of anims) {
          if (layer.anims[anim]) sheetBytes(layer.anims[anim].url);
          if (layer.mask?.[anim]) sheetBytes(layer.mask[anim].url);
        }
      }
    },
    /** Where the character's head and feet are inside a frame. */
    bounds(recipe) {
      const r = parseRecipe(recipe, catalog);
      return catalog.bodies[r?.body] ?? Object.values(catalog.bodies)[0];
    },
    frames(anim) {
      return catalog.anims[anim]?.frames ?? 0;
    },
    get cachedBytes() {
      return strips.bytes + sources.bytes;
    },
  };
}
