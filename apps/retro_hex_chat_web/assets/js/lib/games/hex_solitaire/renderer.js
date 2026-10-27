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
import { drawDigit, drawParticleDots, drawPixelSprite } from "../core/render.js";
import { flightAt, flipWidth, flying, shakeAt } from "./effects.js";
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

const STAR = ["..#..", "..#..", "#####", ".###.", ".#.#.", "#...#"];
const CLOCK = [".###.", "#.#.#", "#.#.#", "#.###", "#...#", ".###."];
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

/** A number in pixel digits from its left edge; answers where it ended. */
function drawNumber(ctx, text, x, y) {
  let left = x;
  for (const char of String(text)) {
    if (char === ":") {
      ctx.fillRect(left, y + 4, 2, 2);
      ctx.fillRect(left, y + 10, 2, 2);
      left += 5;
    } else {
      drawDigit(ctx, Number(char), left, y, 2);
      left += 12;
    }
  }
  return left;
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
 *   colors: object, now: number, back: number, trail?: object | null }} scene
 */
export function render(ctx, { state, drag, fx, atlas, colors, now, back, trail = null }) {
  const { table } = state;
  const places = layout(table);
  const away = flying(fx);
  if (drag) for (const card of drag.cards) away.add(card);
  const shaking = new Map(
    fx.list.filter((e) => e.kind === "shake").map((e) => [e.card, shakeAt(e, now)]),
  );
  const turning = new Map(
    fx.list.filter((e) => e.kind === "flip").map((e) => [e.card, flipWidth(e, now)]),
  );
  const one = (card, x, y, faceUp = true) =>
    drawOne(ctx, atlas, card, x + (shaking.get(card) ?? 0), y, {
      faceUp,
      back,
      width: turning.get(card) ?? CARD.width,
    });

  ctx.fillStyle = colors.felt;
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
      effect.cards.forEach((card, i) => {
        drawOne(ctx, atlas, card, at.x, at.y + i * 18, { faceUp: effect.faceUp ?? true, back });
      });
    }
    if (effect.kind === "sparks") drawParticleDots(ctx, effect.particles);
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
  ctx.fillStyle = colors.ink;
  drawPixelSprite(ctx, STAR, { "#": colors.ink }, 8, 4, 2, 2);
  drawNumber(ctx, state.score, 22, 4);
  const time = clock(state.clock.ticks);
  const right = VIEW.width - 8 - (time.length - 1) * 12 - 5;
  drawPixelSprite(ctx, CLOCK, { "#": colors.ink }, right - 14, 4, 2, 2);
  drawNumber(ctx, time, right, 4);
}
