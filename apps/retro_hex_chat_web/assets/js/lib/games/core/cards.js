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
import { browserAtlasIO, createAtlasLoader } from "./atlas.js";

/** The 52 cards, in suit order. */
export const DECK = Object.freeze(Array.from({ length: 52 }, (_, id) => id));

/** The suits, by the number `suitOf` answers. */
export const SUIT = Object.freeze({ SPADES: 0, HEARTS: 1, DIAMONDS: 2, CLUBS: 3 });

/** A card's size on the canvas when no atlas says otherwise. */
export const FULL_CARD = Object.freeze({ width: 64, height: 88 });

/** The mini card's size, for tables of many columns on a phone. */
export const MINI_CARD = Object.freeze({ width: 44, height: 62 });

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
 * The picture a card shows. Games of two decks number their cards past 51 —
 * `copy * 52 + face` — so two cards that look alike are still two cards.
 * @param {number} card
 * @returns {number} 0 to 51
 */
export const faceOf = (card) => card % 52;

/**
 * Spider's 104 cards: eight of each rank, in one suit (spades), two (spades
 * and hearts) or all four, each a distinct number whose `faceOf` is its picture.
 * @param {1 | 2 | 4} suits
 * @returns {number[]}
 */
export function spiderDeck(suits) {
  const cards = [];
  for (let copy = 0; copy < 8; copy++) {
    const suit = copy % suits;
    for (let rank = 0; rank < 13; rank++) cards.push(copy * 52 + suit * 13 + rank);
  }
  return cards;
}

/**
 * A loader of card atlases: an atlas is a JSON description (`card`, the size a
 * card is drawn at; `faces`, one region per card; `backs`, one per back;
 * `image`, the picture's file beside it) and the picture it cuts from
 * (`core/atlas.js`). An incomplete one is refused.
 *
 * @param {{ fetchJson: (url: string) => Promise<object>, loadImage: (src: string) => Promise<CanvasImageSource> }} io
 * @returns {(url: string) => Promise<object>}
 */
export function createCardAtlasLoader(io) {
  return createAtlasLoader(io, (description, url) => {
    if (description?.faces?.length !== ATLAS_FACES) {
      throw new Error(`card atlas ${url} needs ${ATLAS_FACES} faces`);
    }
    if (!((description.backs?.length ?? 0) >= ATLAS_BACKS)) {
      throw new Error(`card atlas ${url} needs ${ATLAS_BACKS} backs`);
    }
  });
}

const RANK_NAMES = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
const SUIT_SIGNS = ["♠", "♥", "♦", "♣"];

/**
 * Draw one card at `x`, `y` (its top-left corner), at the atlas's card size —
 * or the mini card's, with `size: "mini"`: its face, or a back when it lies
 * face down. Until the atlas has loaded — or
 * if it never does — a plain card stands in that still says what it is, its
 * rank and suit in a corner, and a dark back face down, so the game can be
 * played without its pictures.
 *
 * @param {CanvasRenderingContext2D} ctx
 * @param {object | null} atlas - what `createCardAtlasLoader` resolved, or null
 * @param {number} card
 * @param {number} x
 * @param {number} y
 * @param {{ faceUp?: boolean, back?: number, size?: "full" | "mini" }} [options]
 * @returns {void}
 */
export function drawCard(ctx, atlas, card, x, y, { faceUp = true, back = 0, size = "full" } = {}) {
  const pictures = size === "mini" ? atlas?.mini : atlas;
  const { width, height } = pictures?.card ?? (size === "mini" ? MINI_CARD : FULL_CARD);
  if (!pictures) {
    ctx.fillStyle = gameColor("f4f1e8");
    ctx.fillRect(x, y, width, height);
    ctx.strokeStyle = gameColor("1a1a1a");
    ctx.strokeRect(x, y, width, height);
    if (faceUp) {
      ctx.fillStyle = isRed(card) ? gameColor("c51316") : gameColor("090101");
      ctx.font = "bold 12px monospace";
      ctx.fillText(`${RANK_NAMES[rankOf(card) - 1]}${SUIT_SIGNS[suitOf(card)]}`, x + 4, y + 14);
    } else {
      ctx.fillStyle = gameColor("0e2369");
      ctx.fillRect(x + 3, y + 3, width - 6, height - 6);
    }
    return;
  }
  const region = faceUp ? pictures.faces[card] : pictures.backs[back];
  ctx.drawImage(atlas.image, region.x, region.y, region.w, region.h, x, y, width, height);
}

/**
 * Where the platform's deck is served, with the version of its description
 * (`assets/art/cards/build_deck.py` writes it): a deck rebuilt is a new address,
 * so no browser reads it from an old cache.
 */
export const CARD_ATLAS_URL = "/images/games/cards/cards.json?vsn=7725fd890adb";

/**
 * A loader that reads card atlases the way a browser does.
 * @returns {(url: string) => Promise<object>}
 */
export const browserCardAtlasLoader = () => createCardAtlasLoader(browserAtlasIO);
