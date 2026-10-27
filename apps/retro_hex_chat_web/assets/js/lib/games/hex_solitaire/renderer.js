/**
 * Hex Solitaire's picture: the felt, the piles and their cards, what is
 * moving over them, and the score and the time above. No words: digits and
 * pixel icons, so nothing here is translated.
 *
 * Cards come from the platform's card atlas (`core/cards.js`); until it has
 * loaded, plain cards stand in.
 *
 * @module games/hex_solitaire/renderer
 */

import { readGameColors } from "../../game_colors.js";
import { drawCard } from "../core/cards.js";
import { drawParticleDots, drawPixelSprite } from "../core/render.js";
import { flightAt, flipShowsFace, flipWidth, flying, shakeAt } from "./effects.js";
import { layout } from "./layout.js";
import { CARD, VIEW } from "./protocol.js";

/** The table's colours, from the canvas's custom properties. */
export function readColors(canvas) {
  return readGameColors(canvas, {
    felt: ["--game-solitaire-felt-color", "08786c"],
    feltDark: ["--game-solitaire-felt-dark-color", "066358"],
    slot: ["--game-solitaire-slot-color", "0a8f80"],
    ink: ["--game-solitaire-ink-color", "fefefe"],
    shadow: ["--game-solitaire-shadow-color", "rgba(0,0,0,0.35)"],
  });
}

// The score's and the clock's icons and digits, in the deck's rank lettering.
const STAR = ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"];
const CLOCK = ["..###..", ".#.#.#.", "#..#..#", "#..##.#", "#.....#", ".#...#.", "..###.."];
const DIGITS = {
  0: [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
  1: ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
  2: [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
  3: ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
  4: ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "..###"],
  5: ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
  6: [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
  7: ["#####", "#...#", "...#.", "..#..", "..#..", ".#...", ".#..."],
  8: [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
  9: [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
  ":": [".", ".", "#", ".", "#", ".", "."],
};
// The deck's own pips (`assets/art/cards/build_deck.py`), marking each foundation's place.
const SUITS = [
  [
    ".....#.....",
    "....###....",
    "...#####...",
    "..#######..",
    ".#########.",
    "###########",
    "###########",
    "###########",
    ".####.####.",
    ".....#.....",
    "....###....",
  ],
  [
    "..###.###..",
    ".#########.",
    "###########",
    "###########",
    "###########",
    ".#########.",
    "..#######..",
    "...#####...",
    "....###....",
    ".....#.....",
  ],
  [
    "....#....",
    "...###...",
    "..#####..",
    "..#####..",
    ".#######.",
    "#########",
    "#########",
    ".#######.",
    "..#####..",
    "..#####..",
    "...###...",
    "....#....",
  ],
  [
    "....###....",
    "...#####...",
    "...#####...",
    "....###....",
    ".##.###.##.",
    "###########",
    "###########",
    ".##..#..##.",
    ".....#.....",
    "....###....",
  ],
];

// The felt's weave: a tile of the felt's colour with a few darker threads.
const WEAVE = [
  "#.......",
  "........",
  "....#...",
  "........",
  "..#.....",
  "........",
  "......#.",
  "........",
];

/**
 * The felt as a pattern of its weave, for `fillStyle`; null where the page
 * cannot draw off the screen (the felt is then plain).
 * @param {CanvasRenderingContext2D} ctx - the screen the pattern is for
 * @param {object} colors
 * @param {Document} document
 */
export function feltWeave(ctx, colors, document) {
  const tile = document.createElement("canvas");
  tile.width = WEAVE[0].length;
  tile.height = WEAVE.length;
  const weave = tile.getContext("2d");
  if (!weave) return null;
  weave.fillStyle = colors.felt;
  weave.fillRect(0, 0, tile.width, tile.height);
  drawPixelSprite(weave, WEAVE, { "#": colors.feltDark }, 0, 0, 1, 1);
  return ctx.createPattern(tile, "repeat");
}

/** How wide a number is in the score's digits, at 2 pixels a dot. */
const numberWidth = (text) =>
  [...String(text)].reduce((width, char) => width + (DIGITS[char][0].length + 1) * 2, 0);

/** A number in the score's digits from its left edge. */
function drawNumber(ctx, text, x, y, ink) {
  let left = x;
  for (const char of String(text)) {
    drawPixelSprite(ctx, DIGITS[char], { "#": ink }, left, y, 2, 2);
    left += (DIGITS[char][0].length + 1) * 2;
  }
}

const clock = (ticks) => {
  const seconds = Math.floor(ticks / 60);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
};

/** An empty pile's place: a darker outline on the felt, and a suit for a foundation. */
function drawSlot(ctx, place, colors, suit = null) {
  ctx.strokeStyle = colors.slot;
  ctx.lineWidth = 2;
  ctx.strokeRect(place.x + 1, place.y + 1, CARD.width - 2, CARD.height - 2);
  if (suit !== null) {
    const pip = SUITS[suit];
    const x = place.x + Math.floor((CARD.width - pip[0].length * 2) / 2);
    const y = place.y + Math.floor((CARD.height - pip.length * 2) / 2);
    drawPixelSprite(ctx, pip, { "#": colors.slot }, x, y, 2, 2);
  }
}

function drawShadow(ctx, x, y, colors, lift = 0) {
  ctx.fillStyle = colors.shadow;
  ctx.fillRect(x + 2 + lift, y + 2 + lift, CARD.width, CARD.height);
}

/** One card at its place, face up or down, narrowed while it turns over. */
function drawOne(ctx, atlas, card, x, y, { faceUp = true, back = 0, width = CARD.width } = {}) {
  if (width <= 0) return;
  if (width === CARD.width) {
    drawCard(ctx, atlas, card, x, y, { faceUp, back });
    return;
  }
  ctx.save();
  ctx.translate(x + (CARD.width - width) / 2, y);
  ctx.scale(width / CARD.width, 1);
  drawCard(ctx, atlas, card, 0, 0, { faceUp, back });
  ctx.restore();
}

/**
 * The whole picture.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ state: object, drag: object | null, fx: object, atlas: object | null,
 *   colors: object, now: number, back: number, trail?: object | null,
 *   felt?: CanvasPattern | null }} scene - `felt` is the felt's weave, when the
 *   page could make one; the felt is plain without it
 */
export function render(
  ctx,
  { state, drag, fx, atlas, colors, now, back, trail = null, felt = null },
) {
  const { table } = state;
  const places = layout(table);
  const away = flying(fx);
  if (drag) for (const card of drag.cards) away.add(card);
  // A card the cascade has launched has left its foundation.
  for (const effect of fx.list) {
    if (effect.kind !== "cascade") continue;
    for (const item of effect.items) if (now >= item.launch) away.add(item.card);
  }
  const shaking = new Map(
    fx.list.filter((e) => e.kind === "shake").map((e) => [e.card, shakeAt(e, now)]),
  );
  const turning = new Map(fx.list.filter((e) => e.kind === "flip").map((e) => [e.card, e]));
  const one = (card, x, y, faceUp = true) => {
    const flip = turning.get(card);
    drawOne(ctx, atlas, card, x + (shaking.get(card) ?? 0), y, {
      faceUp: flip ? flipShowsFace(flip, now) : faceUp,
      back,
      width: flip ? flipWidth(flip, now) : CARD.width,
    });
  };

  ctx.fillStyle = felt ?? colors.felt;
  ctx.fillRect(0, 0, VIEW.width, VIEW.height);
  ctx.fillStyle = colors.feltDark;
  ctx.fillRect(0, 0, VIEW.width, 22);

  // The stock, the waste and the foundations.
  if (table.stock.length) one(table.stock.at(-1), places.stock.x, places.stock.y, false);
  else drawSlot(ctx, places.stock, colors);
  if (!places.waste.length) drawSlot(ctx, places.wasteSlot, colors);
  else if (table.waste.length > places.waste.length) {
    // The card under the fan shows while the fan's top flies.
    const under = table.waste[table.waste.length - places.waste.length - 1];
    if (!away.has(under)) one(under, places.wasteSlot.x, places.wasteSlot.y);
  }
  for (const place of places.waste) if (!away.has(place.card)) one(place.card, place.x, place.y);
  places.foundations.forEach((place, suit) => {
    const pile = table.foundations[suit];
    const shown = [...pile].reverse().find((card) => !away.has(card));
    if (shown === undefined) drawSlot(ctx, place, colors, suit);
    else one(shown, place.x, place.y);
  });

  // The columns.
  for (const column of places.columns) {
    if (!column.cards.length) drawSlot(ctx, column.slot, colors);
    for (const c of column.cards) if (!away.has(c.card)) one(c.card, c.x, c.y, c.faceUp);
  }

  // What moves over the table.
  for (const effect of fx.list) {
    if (effect.kind === "flight" && now >= effect.start) {
      const at = flightAt(effect, now);
      // In the air: a shadow on the felt below, until it lands.
      if (now < effect.start + effect.ticks) {
        effect.cards.forEach((card, k) => drawShadow(ctx, at.x, at.y + k * 18, colors, 1));
      }
      effect.cards.forEach((card, i) => {
        drawOne(ctx, atlas, card, at.x, at.y + i * 18, { faceUp: effect.faceUp ?? true, back });
      });
    }
    if (effect.kind === "sparks" && now >= effect.start) drawParticleDots(ctx, effect.particles);
    if (effect.kind === "cascade") {
      const target = trail ? trail.ctx : ctx;
      for (const item of effect.items) {
        if (now >= item.launch && !item.gone) {
          drawCard(target, atlas, item.card, Math.round(item.x), Math.round(item.y));
        }
      }
      trail?.drawTo(ctx);
    }
  }
  if (drag) {
    drag.cards.forEach((card, i) => drawShadow(ctx, drag.x, drag.y - 2 + i * 18, colors, 2));
    drag.cards.forEach((card, i) =>
      drawOne(ctx, atlas, card, drag.x, drag.y - 2 + i * 18, { back }),
    );
  }

  // The score and the time.
  drawPixelSprite(ctx, STAR, { "#": colors.ink }, 8, 4, 2, 2);
  drawNumber(ctx, state.score, 26, 4, colors.ink);
  const time = clock(state.clock.ticks);
  const left = VIEW.width - 8 - numberWidth(time);
  drawPixelSprite(ctx, CLOCK, { "#": colors.ink }, left - 18, 4, 2, 2);
  drawNumber(ctx, time, left, 4, colors.ink);
}
