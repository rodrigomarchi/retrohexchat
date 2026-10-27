/**
 * Art atlases: a JSON description (whatever regions a game cuts, and `image`,
 * the picture's file beside it, its address carrying its version) and the
 * picture itself. Each atlas is fetched once however many ask; a game may
 * refuse one that lacks what it draws.
 *
 * @module games/core/atlas
 */

/**
 * A loader of atlases.
 * @param {{ fetchJson: (url: string) => Promise<object>, loadImage: (src: string) => Promise<CanvasImageSource> }} io
 * @param {(description: object, url: string) => void} [check] - throws on an atlas it refuses
 * @returns {(url: string) => Promise<object>} the description, its `image` the loaded picture
 */
export function createAtlasLoader({ fetchJson, loadImage }, check = () => {}) {
  const loading = new Map();

  async function read(url) {
    const description = await fetchJson(url);
    check(description, url);
    const image = new URL(description.image, new URL(url, "http://atlas.invalid"));
    return { ...description, image: await loadImage(image.pathname + image.search) };
  }

  return (url) => {
    if (!loading.has(url)) loading.set(url, read(url));
    return loading.get(url);
  };
}

/** How a browser reads an atlas: the description by `fetch`, the picture by an `Image`. */
export const browserAtlasIO = Object.freeze({
  fetchJson: async (url) => {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`atlas ${url}: HTTP ${response.status}`);
    return response.json();
  },
  loadImage: (src) =>
    new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve(image);
      image.onerror = () => reject(new Error(`atlas picture ${src} did not load`));
      image.src = src;
    }),
});

/**
 * A region of an atlas drawn into a place `r` (`{ x, y, w, h }`), or a plain
 * square of `fallback` while the atlas loads.
 */
export function drawPiece(ctx, atlas, name, r, fallback) {
  if (!atlas) {
    ctx.fillStyle = fallback;
    ctx.fillRect(r.x, r.y, r.w, r.h);
    return;
  }
  const a = atlas.regions[name];
  ctx.drawImage(atlas.image, a.x, a.y, a.w, a.h, r.x, r.y, r.w, r.h);
}
