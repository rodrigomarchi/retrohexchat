/**
 * What moves on a card table, apart from the match: the deal flying out, a
 * card flying to its place or back where it came from, a refused card
 * shaking, a card turning over, the sparks of a foundation and the cascade
 * of a win.
 *
 * The match changes in the tick; these only draw it arriving. Each is
 * measured in ticks from the tick it began, and any randomness comes from
 * the match's effects stream (`game.fxRandom`), so a seed draws the same
 * pictures. A new gesture ends every movement at once (`settle`). With motion
 * reduced, the cards go straight to their places and a win is a few sparks.
 *
 * A game says where its cards go (its layout); this module makes them move.
 *
 * @module games/core/card_table/effects
 */

import { gameColor } from "../../../game_colors.js";
import { FULL_CARD, MINI_CARD } from "../cards.js";
import { burst, stepParticles } from "../render.js";
import { easeOutBack, easeOutCubic, progress, tweenPoint } from "../tween.js";

/** How long each effect lasts, in ticks (drawing only; the match never waits). */
export const FX = Object.freeze({
  dealStagger: 3,
  dealFlight: 12,
  flight: 10,
  drop: 6,
  return: 8,
  draw: 8,
  shake: 12,
  flip: 8,
  sparks: 20,
  cascadeStagger: 8,
});

const GRAVITY = 0.6;
const BOUNCE = 0.72;

/**
 * The effects of one match, for cards of the `size` the table is dealt in
 * (`"full"` or `"mini"`, `core/cards.js`); `card` is that size in pixels.
 * @returns {{ reduced: boolean, size: string, card: { width: number, height: number },
 *   list: object[] }}
 */
export const createEffects = ({ reduced = false, size = "full" } = {}) => ({
  reduced,
  size,
  card: size === "mini" ? MINI_CARD : FULL_CARD,
  list: [],
});

/** Cards flying from the place `from` to the place `to`, from tick `start`. */
export function addFlight(fx, cards, from, to, start, ticks, ease, extra = {}) {
  if (fx.reduced) return;
  fx.list.push({ kind: "flight", cards, from, to, start, ticks, ease, ...extra });
}

/**
 * The deal: in rounds, one card to each column still short, left to right,
 * every card flying out from the place `from`.
 * @param {object} fx
 * @param {Array<{ cards: object[] }>} columns - each column's laid cards (`piles.columnCards`)
 * @param {{ x: number, y: number }} from
 * @param {number} now
 */
export function dealEffects(fx, columns, from, now) {
  let order = 0;
  const rows = Math.max(0, ...columns.map((column) => column.cards.length));
  for (let row = 0; row < rows; row++) {
    for (const column of columns) {
      const card = column.cards[row];
      if (!card) continue;
      addFlight(
        fx,
        [card.card],
        from,
        card,
        now + order * FX.dealStagger,
        FX.dealFlight,
        easeOutCubic,
        {
          faceUp: card.faceUp,
        },
      );
      order += 1;
    }
  }
}

/**
 * A move's effects: its cards flying from where they were (or were dropped)
 * to where they land, the card it uncovered turning over, and sparks when it
 * landed on a foundation.
 * @param {object} fx
 * @param {{ cards: number[], from: { x: number, y: number }, to: { x: number, y: number },
 *   dropped: boolean, now: number, turned?: object | null, sparksAt?: object | null,
 *   random: () => number }} move
 */
export function moveEffects(
  fx,
  { cards, from, to, dropped, now, turned = null, sparksAt = null, random },
) {
  addFlight(
    fx,
    cards,
    from,
    to,
    now,
    dropped ? FX.drop : FX.flight,
    dropped ? easeOutCubic : easeOutBack,
  );
  if (turned && !fx.reduced) {
    fx.list.push({ kind: "flip", card: turned.card, at: turned, start: now, ticks: FX.flip });
  }
  // The sparks go off as the card lands.
  const landed = now + (fx.reduced ? 0 : dropped ? FX.drop : FX.flight);
  if (sparksAt) sparks(fx, sparksAt, landed, random);
}

/** A dragged run going back to the place it was picked up from. */
export function returnEffects(fx, drag, home, now) {
  addFlight(fx, drag.cards, { x: drag.x, y: drag.y }, home, now, FX.return, easeOutBack);
}

/** A card with nowhere to go, shaking where it lies. */
export function shakeEffects(fx, card, place, now) {
  if (fx.reduced) return;
  fx.list.push({ kind: "shake", card, at: place, start: now, ticks: FX.shake });
}

const SPARK_COLOURS = ["ffd34d", "fff6c8", "ffffff"];

/** Sparks flying out from the edge of a pile, gold and white, from tick `start`. */
export function sparks(fx, place, start, random) {
  const { width, height } = fx.card;
  const cx = place.x + width / 2;
  const cy = place.y + height / 2;
  const particles = burst(
    cx,
    cy,
    fx.reduced ? 6 : 16,
    {
      speed: [1.5, 2.5],
      extra: (i) => ({ life: 1, color: gameColor(SPARK_COLOURS[i % SPARK_COLOURS.length]) }),
    },
    random,
  ).map((p) => {
    // Out from the card's edge, not its middle: the card hides its middle.
    const reach = Math.min(width / 2 / Math.abs(p.vx || 1e-6), height / 2 / Math.abs(p.vy || 1e-6));
    return { ...p, x: cx + p.vx * reach, y: cy + p.vy * reach };
  });
  fx.list.push({ kind: "sparks", particles, start, ticks: FX.sparks });
}

/**
 * A win: the cards leave the foundations one after another, the top of each
 * pile in turn, and bounce along the felt until they are off it. With motion
 * reduced, sparks on each foundation.
 * @param {object} fx
 * @param {Array<{ place: { x: number, y: number }, cards: number[] }>} piles - bottom card first
 * @param {{ width: number, height: number }} view
 * @param {number} now
 * @param {() => number} random
 */
export function cascadeEffects(fx, piles, view, now, random) {
  if (fx.reduced) {
    for (const { place } of piles) sparks(fx, place, now, random);
    return;
  }
  const items = [];
  const height = Math.max(0, ...piles.map((pile) => pile.cards.length));
  for (let level = height - 1; level >= 0; level--) {
    for (const { place, cards } of piles) {
      if (cards[level] === undefined) continue;
      items.push({
        card: cards[level],
        x: place.x,
        y: place.y,
        vx: -(2 + random() * 3) * (random() < 0.5 ? 1 : -1),
        vy: -random() * 4,
        launch: now + items.length * FX.cascadeStagger,
      });
    }
  }
  fx.list.push({ kind: "cascade", items, view, start: now, ticks: Infinity });
}

/** One tick of the effects that move by themselves: the sparks and the cascade. */
export function stepEffects(fx, now) {
  const { width, height } = fx.card;
  fx.list = fx.list.filter((effect) => {
    if (effect.kind === "sparks") {
      if (now < effect.start) return true;
      effect.particles = stepParticles(effect.particles, { drag: 0.9, fade: 1 / FX.sparks });
      return effect.particles.length > 0;
    }
    if (effect.kind === "cascade") {
      for (const item of effect.items) {
        if (now < item.launch || item.gone) continue;
        item.x += item.vx;
        item.vy += GRAVITY;
        item.y += item.vy;
        if (item.y > effect.view.height - height) {
          item.y = effect.view.height - height;
          item.vy = -item.vy * BOUNCE;
        }
        if (item.x < -width || item.x > effect.view.width) item.gone = true;
      }
      return effect.items.some((item) => !item.gone);
    }
    return now < effect.start + effect.ticks;
  });
}

/** End every movement now: the cards are where the match put them. */
export function settle(fx) {
  fx.list = fx.list.filter((effect) => effect.kind === "sparks" || effect.kind === "cascade");
}

/** Whether anything still moves, so a frame is worth drawing. */
export const active = (fx) => fx.list.length > 0;

/** The cards in flight (or waiting to fly), which the table leaves out. */
export function flying(fx) {
  const cards = new Set();
  for (const effect of fx.list) {
    if (effect.kind === "flight") for (const card of effect.cards) cards.add(card);
  }
  return cards;
}

/** Where a flight's first card is at `now`, on whole pixels. */
export const flightAt = (effect, now) =>
  tweenPoint(effect.from, effect.to, progress(effect.start, effect.ticks, now), effect.ease);

/** How far a shaking card is pushed sideways at `now`. */
export function shakeAt(effect, now) {
  const t = progress(effect.start, effect.ticks, now);
  return Math.round(Math.sin(t * Math.PI * 6) * 4 * (1 - t)) || 0;
}

/** Whether a turning card already shows its face: the back narrows, the face opens. */
export const flipShowsFace = (effect, now) => progress(effect.start, effect.ticks, now) >= 0.5;

// A card turning over shows these shares of its width, a step each.
const FLIP_STEPS = [64, 48, 32, 12, 12, 32, 48, 64];

/** How wide a turning card of `width` pixels shows at `now`: narrowing to an edge and opening again. */
export function flipWidth(effect, now, width = FULL_CARD.width) {
  const t = progress(effect.start, effect.ticks, now);
  const step = FLIP_STEPS[Math.min(FLIP_STEPS.length - 1, Math.floor(t * FLIP_STEPS.length))];
  return Math.round((step * width) / FLIP_STEPS[0]);
}
