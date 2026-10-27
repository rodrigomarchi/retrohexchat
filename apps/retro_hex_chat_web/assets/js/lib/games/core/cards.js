/**
 * A deck of playing cards: the 52 cards, their suits, ranks and colours, the
 * shuffle a seed replays, and their pictures cut out of one art atlas.
 *
 * A card is a number from 0 to 51: suit by suit (spades, hearts, diamonds,
 * clubs), each from the ace to the king, so `suitOf(id)` is `id / 13` and
 * `rankOf(id)` runs 1 (ace) to 13 (king). Every card game draws from the same
 * deck and the same atlas. A module of its own, so the other games do not
 * load it.
 *
 * @module games/core/cards
 */

import { gameColor } from "../../game_colors.js";

/** The 52 cards, in suit order. */
export const DECK = Object.freeze(Array.from({ length: 52 }, (_, id) => id));

/** The suits, by the number `suitOf` answers. */
export const SUIT = Object.freeze({ SPADES: 0, HEARTS: 1, DIAMONDS: 2, CLUBS: 3 });

/** A card's size on the canvas when no atlas says otherwise. */
const DEFAULT_CARD = Object.freeze({ width: 64, height: 88 });

const ATLAS_FACES = 52;
const ATLAS_BACKS = 4;

/** @param {number} card @returns {number} 0 spades, 1 hearts, 2 diamonds, 3 clubs */
export const suitOf = (card) => Math.floor(card / 13);

/** @param {number} card @returns {number} 1 (ace) to 13 (king) */
export const rankOf = (card) => (card % 13) + 1;

/** @param {number} card @returns {boolean} hearts and diamonds */
export const isRed = (card) => suitOf(card) === SUIT.HEARTS || suitOf(card) === SUIT.DIAMONDS;

/**
 * The cards in a new order (Fisher–Yates), drawn from `random`; the cards
 * given are left as they were.
 * @param {ReadonlyArray<number>} cards
 * @param {() => number} random - the match's generator, so a seed replays the deal
 * @returns {number[]}
 */
export function shuffle(cards, random) {
  const order = [...cards];
  for (let i = order.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [order[i], order[j]] = [order[j], order[i]];
  }
  return order;
}

/**
 * A loader of card atlases: an atlas is a JSON description (`card`, the size a
 * card is drawn at; `faces`, one region per card; `backs`, one per back;
 * `image`, the picture's file beside it) and the picture it cuts from. Each
 * atlas is fetched once however many ask, and an incomplete one is refused.
 *
 * @param {{ fetchJson: (url: string) => Promise<object>, loadImage: (src: string) => Promise<CanvasImageSource> }} io
 * @returns {(url: string) => Promise<object>}
 */
export function createCardAtlasLoader({ fetchJson, loadImage }) {
  const loading = new Map();

  return (url) => {
    if (!loading.has(url)) loading.set(url, readAtlas(url, fetchJson, loadImage));
    return loading.get(url);
  };
}

async function readAtlas(url, fetchJson, loadImage) {
  const description = await fetchJson(url);
  if (description?.faces?.length !== ATLAS_FACES) {
    throw new Error(`card atlas ${url} needs ${ATLAS_FACES} faces`);
  }
  if (!((description.backs?.length ?? 0) >= ATLAS_BACKS)) {
    throw new Error(`card atlas ${url} needs ${ATLAS_BACKS} backs`);
  }
  const src = new URL(description.image, new URL(url, "http://atlas.invalid")).pathname;
  return { ...description, image: await loadImage(src) };
}

/**
 * Draw one card at `x`, `y` (its top-left corner), at the atlas's card size:
 * its face, or a back when it lies face down. Until the atlas has loaded, a
 * plain card stands in, so a frame drawn early is never a failure.
 *
 * @param {CanvasRenderingContext2D} ctx
 * @param {object | null} atlas - what `createCardAtlasLoader` resolved, or null
 * @param {number} card
 * @param {number} x
 * @param {number} y
 * @param {{ faceUp?: boolean, back?: number }} [options]
 * @returns {void}
 */
export function drawCard(ctx, atlas, card, x, y, { faceUp = true, back = 0 } = {}) {
  const { width, height } = atlas?.card ?? DEFAULT_CARD;
  if (!atlas) {
    ctx.fillStyle = gameColor("f4f1e8");
    ctx.fillRect(x, y, width, height);
    ctx.strokeStyle = gameColor("1a1a1a");
    ctx.strokeRect(x, y, width, height);
    return;
  }
  const region = faceUp ? atlas.faces[card] : atlas.backs[back];
  ctx.drawImage(atlas.image, region.x, region.y, region.w, region.h, x, y, width, height);
}

/** Where the platform's deck is served. */
export const CARD_ATLAS_URL = "/images/games/cards/cards.json";

/**
 * A loader that reads atlases the way a browser does: the description by
 * `fetch`, the picture by an `Image`.
 * @returns {(url: string) => Promise<object>}
 */
export function browserCardAtlasLoader() {
  return createCardAtlasLoader({
    fetchJson: async (url) => {
      const response = await fetch(url);
      if (!response.ok) throw new Error(`card atlas ${url}: HTTP ${response.status}`);
      return response.json();
    },
    loadImage: (src) =>
      new Promise((resolve, reject) => {
        const image = new Image();
        image.onload = () => resolve(image);
        image.onerror = () => reject(new Error(`card atlas picture ${src} did not load`));
        image.src = src;
      }),
  });
}
