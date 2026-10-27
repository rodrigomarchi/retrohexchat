/**
 * What every card table draws: the felt and its weave, an empty pile's
 * place, a card resting, turning over or shaking, what moves over the table
 * (flights, sparks, the cascade, the run held), and the score and the time
 * above. No words: digits and pixel icons, so nothing here is translated.
 *
 * Cards come from the platform's card atlas (`core/cards.js`); until it has
 * loaded, plain cards stand in.
 *
 * @module games/core/card_table/render
 */

import { readGameColors } from "../../../game_colors.js";
import { FULL_CARD, drawCard } from "../cards.js";
import { drawParticleDots, drawPixelSprite } from "../render.js";
import { flightAt, flipShowsFace, flipWidth, flying, shakeAt } from "./effects.js";

/** A table's colours, from the canvas's custom properties. */
export function readTableColors(canvas) {
  return readGameColors(canvas, {
    felt: ["--game-cards-felt-color", "08786c"],
    feltDark: ["--game-cards-felt-dark-color", "066358"],
    slot: ["--game-cards-slot-color", "0a8f80"],
    ink: ["--game-cards-ink-color", "fefefe"],
    shadow: ["--game-cards-shadow-color", "rgba(0,0,0,0.35)"],
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

/** The height of the darker band the score and the time sit on. */
export const HUD_HEIGHT = 22;

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

/** The felt over the whole view, and the band the score and the time sit on. */
export function drawFelt(ctx, view, colors, felt = null) {
  ctx.fillStyle = felt ?? colors.felt;
  ctx.fillRect(0, 0, view.width, view.height);
  ctx.fillStyle = colors.feltDark;
  ctx.fillRect(0, 0, view.width, HUD_HEIGHT);
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

/** The score at the top left, the time at the top right. */
export function drawHud(ctx, view, { score, ticks }, colors) {
  drawPixelSprite(ctx, STAR, { "#": colors.ink }, 8, 4, 2, 2);
  drawNumber(ctx, score, 26, 4, colors.ink);
  const time = clock(ticks);
  const left = view.width - 8 - numberWidth(time);
  drawPixelSprite(ctx, CLOCK, { "#": colors.ink }, left - 18, 4, 2, 2);
  drawNumber(ctx, time, left, 4, colors.ink);
}

/**
 * An empty pile's place: a darker outline on the felt, and a suit for a
 * foundation, or any other pixel icon (`mark`, rows of `#`).
 */
export function drawSlot(ctx, place, colors, { suit = null, mark = null, card = FULL_CARD } = {}) {
  ctx.strokeStyle = colors.slot;
  ctx.lineWidth = 2;
  ctx.strokeRect(place.x + 1, place.y + 1, card.width - 2, card.height - 2);
  const icon = suit !== null ? SUITS[suit] : mark;
  if (icon) {
    const x = place.x + Math.floor((card.width - icon[0].length * 2) / 2);
    const y = place.y + Math.floor((card.height - icon.length * 2) / 2);
    drawPixelSprite(ctx, icon, { "#": colors.slot }, x, y, 2, 2);
  }
}

function drawShadow(ctx, x, y, colors, card, lift = 0) {
  ctx.fillStyle = colors.shadow;
  ctx.fillRect(x + 2 + lift, y + 2 + lift, card.width, card.height);
}

/** One card at its place, face up or down, narrowed while it turns over. */
function drawOne(ctx, atlas, id, x, y, { faceUp = true, back = 0, width, card }) {
  if (width <= 0) return;
  if (width === card.width) {
    drawCard(ctx, atlas, id, x, y, { faceUp, back });
    return;
  }
  ctx.save();
  ctx.translate(x + (card.width - width) / 2, y);
  ctx.scale(width / card.width, 1);
  drawCard(ctx, atlas, id, 0, 0, { faceUp, back });
  ctx.restore();
}

/**
 * What draws the cards resting on the table this frame: `one(card, x, y,
 * faceUp)` draws a card where it lies — shaking or turning over if it is —
 * and `away` holds the cards that are not there to draw (flying, held, or
 * launched by the cascade).
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ fx: object, drag: object | null, atlas: object | null, now: number, back: number,
 *   face?: (card: number) => number }} scene - `face` is the picture a card shows,
 *   for decks where two cards look alike
 * @returns {{ away: Set<number>, one: (card: number, x: number, y: number, faceUp?: boolean) => void }}
 */
export function tablePainter(ctx, { fx, drag, atlas, now, back, face = (card) => card }) {
  const card = fx.card;
  const away = flying(fx);
  if (drag) for (const held of drag.cards) away.add(held);
  // A card the cascade has launched has left its foundation.
  for (const effect of fx.list) {
    if (effect.kind !== "cascade") continue;
    for (const item of effect.items) if (now >= item.launch) away.add(item.card);
  }
  const shaking = new Map(
    fx.list.filter((e) => e.kind === "shake").map((e) => [e.card, shakeAt(e, now)]),
  );
  const turning = new Map(fx.list.filter((e) => e.kind === "flip").map((e) => [e.card, e]));
  const one = (id, x, y, faceUp = true) => {
    const flip = turning.get(id);
    drawOne(ctx, atlas, face(id), x + (shaking.get(id) ?? 0), y, {
      faceUp: flip ? flipShowsFace(flip, now) : faceUp,
      back,
      width: flip ? flipWidth(flip, now, card.width) : card.width,
      card,
    });
  };
  return { away, one };
}

/**
 * What moves over the table: the cards in flight with their shadows, the
 * sparks, the cascade (on its trail layer when there is one), and last the
 * run held, lifted.
 * @param {CanvasRenderingContext2D} ctx
 * @param {{ fx: object, drag: object | null, atlas: object | null, now: number, back: number,
 *   colors: object, run: number, trail?: object | null, face?: (card: number) => number }} scene -
 *   `run` is how far apart a run's cards stand
 */
export function drawMoving(
  ctx,
  { fx, drag, atlas, now, back, colors, run, trail = null, face = (card) => card },
) {
  const card = fx.card;
  for (const effect of fx.list) {
    if (effect.kind === "flight" && now >= effect.start) {
      const at = flightAt(effect, now);
      // In the air: a shadow on the felt below, until it lands.
      if (now < effect.start + effect.ticks) {
        effect.cards.forEach((id, k) => drawShadow(ctx, at.x, at.y + k * run, colors, card, 1));
      }
      effect.cards.forEach((id, i) => {
        drawOne(ctx, atlas, face(id), at.x, at.y + i * run, {
          faceUp: effect.faceUp ?? true,
          back,
          width: card.width,
          card,
        });
      });
    }
    if (effect.kind === "sparks" && now >= effect.start) drawParticleDots(ctx, effect.particles);
    if (effect.kind === "cascade") {
      const target = trail ? trail.ctx : ctx;
      for (const item of effect.items) {
        if (now >= item.launch && !item.gone) {
          drawCard(target, atlas, face(item.card), Math.round(item.x), Math.round(item.y));
        }
      }
      trail?.drawTo(ctx);
    }
  }
  if (drag) {
    drag.cards.forEach((id, i) => drawShadow(ctx, drag.x, drag.y - 2 + i * run, colors, card, 2));
    drag.cards.forEach((id, i) =>
      drawOne(ctx, atlas, face(id), drag.x, drag.y - 2 + i * run, {
        back,
        width: card.width,
        card,
      }),
    );
  }
}
