/**
 * What moves on the table, apart from the match: the deal flying out, a card
 * flying to its place or back where it came from, a refused card shaking, a
 * card turning over, the sparks of a foundation and the cascade of a win.
 *
 * The match changes in the tick (`physics.js`); these only draw it arriving.
 * Each is measured in ticks from the tick it began, and any randomness comes
 * from the match's effects stream (`game.fxRandom`), so a seed draws the same
 * pictures. A new gesture ends every movement at once (`settle`). With motion
 * reduced, the cards go straight to their places and a win is a few sparks.
 *
 * @module games/hex_solitaire/effects
 */

import { burst, stepParticles } from "../core/render.js";
import { easeOutBack, easeOutCubic, progress, tweenPoint } from "../core/tween.js";
import { cardsFrom, layout, sourcePlace } from "./layout.js";
import { CARD, EVENT, FX, VIEW } from "./protocol.js";

const GRAVITY = 0.6;
const BOUNCE = 0.72;

/** The effects of one match. */
export const createEffects = ({ reduced = false } = {}) => ({ reduced, list: [] });

const flight = (fx, cards, from, to, start, ticks, ease, extra = {}) => {
  if (fx.reduced) return;
  fx.list.push({ kind: "flight", cards, from, to, start, ticks, ease, ...extra });
};

/** The deal: every card on the table flying out from the stock, one after another. */
export function dealEffects(fx, table, now) {
  const places = layout(table);
  let order = 0;
  for (const column of places.columns) {
    for (const card of column.cards) {
      flight(
        fx,
        [card.card],
        places.stock,
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

/** Where a move's cards land. */
function landing(places, to, count) {
  if (to.pile === "foundation") return places.foundations[to.suit];
  return places.columns[to.col].cards.at(-count);
}

/**
 * The effects of one action from the table (`gestures.js`), from the table
 * before it to the table after, and the events it raised.
 * @param {object} fx
 * @param {{ before: object, after: object, action: object, events: number, now: number,
 *   drag?: object | null, random: () => number }} played
 */
export function actionEffects(fx, { before, after, action, events, now, drag = null, random }) {
  const was = layout(before);
  const is = layout(after);

  if (action.type === "draw") {
    const turned = after.waste.length - before.waste.length;
    is.waste.slice(-turned).forEach((place, i) => {
      flight(fx, [place.card], was.stock, place, now + i * 2, FX.draw, easeOutCubic);
    });
  }
  if (action.type === "move") {
    const { from, to } = action.move;
    const cards = cardsFrom(before, from);
    const start = drag ? { x: drag.x, y: drag.y } : sourcePlace(was, from);
    flight(
      fx,
      cards,
      start,
      landing(is, to, cards.length),
      now,
      drag ? FX.drop : FX.flight,
      drag ? easeOutCubic : easeOutBack,
    );
    if (events & EVENT.FLIP && from.pile === "tableau") {
      const turned = is.columns[from.col].cards.at(-1);
      if (turned && !fx.reduced) {
        fx.list.push({ kind: "flip", card: turned.card, at: turned, start: now, ticks: FX.flip });
      }
    }
    if (events & EVENT.FOUNDATION) sparks(fx, landing(is, to, 1), now, random);
  }
  if (action.type === "return" && drag) {
    flight(
      fx,
      drag.cards,
      { x: drag.x, y: drag.y },
      sourcePlace(was, action.from),
      now,
      FX.return,
      easeOutBack,
    );
  }
  if (action.type === "refuse" && !fx.reduced) {
    const place = sourcePlace(was, action.from);
    fx.list.push({
      kind: "shake",
      card: cardsFrom(before, action.from)[0],
      at: place,
      start: now,
      ticks: FX.shake,
    });
  }
}

/** A few sparks out of the middle of a pile. */
function sparks(fx, place, now, random) {
  const particles = burst(
    place.x + CARD.width / 2,
    place.y + CARD.height / 2,
    fx.reduced ? 4 : 12,
    {
      speed: [1, 2.5],
      extra: () => ({ life: 1 }),
    },
    random,
  );
  fx.list.push({ kind: "sparks", particles, start: now, ticks: FX.sparks });
}

/**
 * A win: the cards leave the foundations one after another and bounce along
 * the felt until they are off it. With motion reduced, sparks on each foundation.
 */
export function cascadeEffects(fx, table, now, random) {
  const places = layout(table);
  if (fx.reduced) {
    for (const place of places.foundations) sparks(fx, place, now, random);
    return;
  }
  const items = [];
  for (let rank = 12; rank >= 0; rank--) {
    for (let suit = 0; suit < 4; suit++) {
      const place = places.foundations[suit];
      items.push({
        card: suit * 13 + rank,
        x: place.x,
        y: place.y,
        vx: -(2 + random() * 3) * (random() < 0.5 ? 1 : -1),
        vy: -random() * 4,
        launch: now + items.length * FX.cascadeStagger,
      });
    }
  }
  fx.list.push({ kind: "cascade", items, start: now, ticks: Infinity });
}

/** One tick of the effects that move by themselves: the sparks and the cascade. */
export function stepEffects(fx, now) {
  fx.list = fx.list.filter((effect) => {
    if (effect.kind === "sparks") {
      effect.particles = stepParticles(effect.particles, { drag: 0.9, fade: 1 / FX.sparks });
      return effect.particles.length > 0;
    }
    if (effect.kind === "cascade") {
      for (const item of effect.items) {
        if (now < item.launch || item.gone) continue;
        item.x += item.vx;
        item.vy += GRAVITY;
        item.y += item.vy;
        if (item.y > VIEW.height - CARD.height) {
          item.y = VIEW.height - CARD.height;
          item.vy = -item.vy * BOUNCE;
        }
        if (item.x < -CARD.width || item.x > VIEW.width) item.gone = true;
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

/** How wide a turning card shows at `now`: narrowing to an edge and opening again. */
export function flipWidth(effect, now) {
  const t = progress(effect.start, effect.ticks, now);
  const steps = [CARD.width, 48, 32, 12, 12, 32, 48, CARD.width];
  return steps[Math.min(steps.length - 1, Math.floor(t * steps.length))];
}
