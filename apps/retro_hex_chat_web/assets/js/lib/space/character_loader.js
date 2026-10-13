/**
 * What the character compositor needs from the browser, in one place: the
 * creator catalog, a piece's bytes, decoding a (recoloured) PNG, and a canvas
 * to compose into. The space's atlas and the creator's preview both build
 * their compositor from these.
 *
 * @module space/character_loader
 */
import { createCharacterCompositor } from "./character_compositor.js";

export function fetchJson(url) {
  return fetch(url, { credentials: "same-origin" }).then((response) => {
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  });
}

export function fetchBytes(url) {
  return fetch(url, { credentials: "same-origin" }).then((response) => {
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.arrayBuffer().then((buffer) => new Uint8Array(buffer));
  });
}

export function decodePng(bytes) {
  return createImageBitmap(new Blob([bytes], { type: "image/png" }));
}

export function makeCanvas(width, height) {
  const canvas =
    typeof OffscreenCanvas === "function"
      ? new OffscreenCanvas(width, height)
      : document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  return canvas;
}

/** A compositor for the catalog at `url`, once it has arrived. */
export function loadCharacters(url, opts = {}) {
  return fetchJson(url).then((catalog) =>
    createCharacterCompositor({
      catalog,
      fetchBytes,
      decode: decodePng,
      makeCanvas,
      ...opts,
    }),
  );
}
