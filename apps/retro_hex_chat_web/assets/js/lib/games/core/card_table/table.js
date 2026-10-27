/**
 * A one-player card game from the parts that are its own. Every card table
 * runs the same match around them: the deal flying out, presses turned into
 * actions, the clock, the cards finishing by themselves, the cascade of a
 * win before the result is told, the back the player chose, the table
 * standing up on a phone held upright, and a frame drawn only while
 * something moves.
 *
 * ```js
 * export default defineCardTable({
 *   name: "HexSolitaire",                          // in the logs
 *   events: EVENT,                                 // the bits a tick raises; their sounds by name
 *   geometry: GEOMETRY,                            // { LANDSCAPE, PORTRAIT }: `view`, `size` ("mini")
 *   init: (game, geometry) => createInitialState(…),
 *   act, step, finalScore,                         // the match, as pure functions of its state
 *   interpret,                                     // `card_table/gestures.js`'s, for the table
 *   hitTest, backTap: (table, hit) => …,           // a tap while waiting that turns the back
 *   effects: { deal, action, cascade, auto },      // what each change draws (`card_table/effects.js`)
 *   render: (ctx, scene) => …,
 * });
 * ```
 *
 * The state is `{ phase, table, score, clock, events, won }`; `step` may move
 * the table by itself (finishing), and `effects.auto(before, after)` says
 * which move it made, so it flies like any other.
 *
 * @module games/core/card_table/table
 */

import { log } from "../../../logger.js";
import { CARD_ATLAS_URL, browserCardAtlasLoader } from "../cards.js";
import { defineGame } from "../define_game.js";
import { playFlags } from "../events.js";
import { createLayer } from "../layers.js";
import { createGesture } from "../pointer.js";
import { soloResult } from "../result.js";
import { active, createEffects, settle, stepEffects } from "./effects.js";
import { feltWeave, readTableColors } from "./render.js";
import { MASTER_VOLUME, SOUNDS } from "./sounds.js";

/**
 * A card match's phases. A win is celebrated — the cascade bounces across the
 * table — before the match is over and its result told, so the page still
 * shows it.
 */
export const PHASE = Object.freeze({
  WAITING: 0,
  PLAYING: 1,
  AUTO_FINISH: 2,
  FINISHED: 3,
  CELEBRATING: 4,
});

/** The longest a celebration lasts; a tap ends it sooner. */
export const CELEBRATION_TICKS = 600;

/** How far a press may move and still be a tap. */
export const TAP_SLOP = 6;

/** The back a player last chose, kept by the browser for every card game. */
const BACK_KEY = "retrohex.cards.back";
const BACKS = 4;

/** The sound of each event bit, by the event's name: `FOUNDATION` plays `foundation`. */
const eventSounds = (events) =>
  Object.entries(events).map(([name, bit]) => [bit, name.toLowerCase()]);

const reducedMotion = () =>
  globalThis.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true;

/**
 * The layer the cascade of a win leaves its trail on, or null where the page
 * cannot draw off the screen (the cascade is then drawn without a trail).
 */
function trailLayer(game) {
  const { width, height } = game.view;
  const layer = createLayer(width, height, game.canvas.width / width, {
    createCanvas: (width, height) => {
      const canvas = game.canvas.ownerDocument.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      return canvas;
    },
  });
  return layer.ctx ? layer : null;
}

/**
 * A card game's definition for `defineGame`.
 * @param {object} table - the game's own parts (see the module's example)
 * @returns {object}
 */
export function defineCardTable(table) {
  const { name, geometry, effects } = table;
  const sounds = eventSounds(table.events);

  function storedBack() {
    try {
      const back = Number(globalThis.localStorage?.getItem(BACK_KEY));
      return Number.isInteger(back) && back >= 0 && back < BACKS ? back : 0;
    } catch (error) {
      log.debug(`[${name}] the chosen back could not be read`, error);
      return 0;
    }
  }

  function storeBack(back) {
    try {
      globalThis.localStorage?.setItem(BACK_KEY, String(back));
    } catch (error) {
      log.debug(`[${name}] the chosen back could not be kept`, error);
    }
  }

  /** An action from the table, played, with the effects it draws. */
  function play(game, action) {
    if (!action) return;
    const before = game.gameState;
    const after = table.act(before, action);
    game.gameState = after;
    effects.action(game.fx, {
      before: before.table,
      after: after.table,
      action,
      events: after.events & ~before.events,
      now: game.frameCount,
      drag: game.heldDrag,
      random: game.fxRandom,
    });
    game.invalidate();
  }

  /** What a press does: in play, a tap or a drag on the table; while waiting, a tap may turn the back. */
  function onPointer(game, event) {
    const s = game.gameState;
    for (const gesture of game.gesture(event)) {
      if (s.phase === PHASE.WAITING) {
        if (
          gesture.type === "tap" &&
          table.backTap?.(s.table, table.hitTest(s.table, gesture.x, gesture.y))
        ) {
          game.back = (game.back + 1) % BACKS;
          storeBack(game.back);
          game.invalidate();
        }
        continue;
      }
      if (game.gameState.phase === PHASE.CELEBRATING) {
        if (gesture.type === "tap") game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
        continue;
      }
      if (game.gameState.phase !== PHASE.PLAYING) continue;
      if (gesture.type === "tap" || gesture.type === "dragStart") settle(game.fx);
      const { drag, action } = table.interpret(game.gameState.table, game.drag, gesture);
      game.heldDrag = game.drag;
      game.drag = drag;
      play(game, action);
      game.heldDrag = null;
      game.invalidate();
    }
  }

  /** One tick of a match in play or finishing by itself. */
  function tick(game) {
    game.frameCount++;
    const second = Math.floor(game.gameState.clock.ticks / 60);
    const events = game.gameState.events;
    const before = game.gameState.table;
    game.gameState = table.step(game.gameState);
    const finished = game.gameState.events;
    if (game.gameState.table !== before) {
      effects.action(game.fx, {
        before,
        after: game.gameState.table,
        action: effects.auto(before, game.gameState.table),
        events: finished,
        now: game.frameCount,
        random: game.fxRandom,
      });
    }
    playFlags(game, sounds, events | finished);
    game.gameState = { ...game.gameState, events: 0 };
    // Something that moved this tick is drawn once more where it came to rest.
    const moving = active(game.fx);
    stepEffects(game.fx, game.frameCount);
    if (
      events ||
      finished ||
      game.drag ||
      moving ||
      Math.floor(game.gameState.clock.ticks / 60) !== second
    ) {
      game.invalidate();
    }
  }

  const portrait = (view) => view.height > view.width;

  return defineGame({
    players: 1,
    pointer: true,
    pixelArt: true,
    resolution: 2,
    inputs: {},
    audio: { sounds: table.sounds ?? SOUNDS, masterVolume: MASTER_VOLUME },
    theme: readTableColors,
    setup: (game) => {
      game.frameCount = 0;
      game.fx = createEffects({ reduced: reducedMotion() });
      game.gesture = createGesture({ slop: TAP_SLOP });
      game.drag = null;
      game.heldDrag = null;
      game.back = storedBack();
      game.atlas = null;
      game.trail = null;
      browserCardAtlasLoader()(CARD_ATLAS_URL)
        .then((atlas) => {
          game.atlas = atlas;
          game.invalidate();
        })
        .catch((error) => log.warn(`[${name}] the card atlas did not load`, error));
    },
    // A phone held upright gives the canvas a box taller than wide: the table
    // stands up in it, so the cards are as big as the phone allows.
    view: (canvas) => {
      const box = canvas.getBoundingClientRect();
      return box.height > box.width ? geometry.PORTRAIT.view : geometry.LANDSCAPE.view;
    },
    init: (game) => table.init(game, portrait(game.view) ? geometry.PORTRAIT : geometry.LANDSCAPE),
    onPointer,
    flow: {
      phases: PHASE,
      initial: "WAITING",
      begin: "PLAYING",
      states: {
        PLAYING: {
          enter: (game) => {
            effects.deal(game.fx, game.gameState.table, game.frameCount);
            game.invalidate();
          },
          tick,
        },
        AUTO_FINISH: { tick },
        // The cascade of a win, before the result is told.
        CELEBRATING: {
          enter: (game) => {
            game.drag = null;
            game.celebration = 0;
            game.trail = reducedMotion() ? null : trailLayer(game);
            effects.cascade(game.fx, game.gameState.table, game.frameCount, game.fxRandom);
            playFlags(game, sounds, game.gameState.events);
            game.gameState = { ...game.gameState, events: 0 };
            game.invalidate();
          },
          tick: (game) => {
            game.frameCount++;
            game.celebration++;
            stepEffects(game.fx, game.frameCount);
            game.invalidate();
            if (!active(game.fx) || game.celebration >= CELEBRATION_TICKS) {
              game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
            }
          },
        },
        FINISHED: {
          final: true,
          enter: (game) => {
            game.drag = null;
            playFlags(game, sounds, game.gameState.events);
            game.invalidate();
            game.finish({ result: soloResult(table.finalScore(game.gameState)) });
          },
        },
      },
    },
    // A match ended mid-celebration keeps the bonus its win earned.
    standing: (game) => soloResult(table.finalScore(game.gameState)),
    render: (game) => {
      // Made once the colours are read; false where the page cannot make one.
      game.felt ??= feltWeave(game.ctx, game.colors, game.canvas.ownerDocument) ?? false;
      return table.render(game.ctx, {
        state: game.gameState,
        drag: game.drag,
        fx: game.fx,
        atlas: game.atlas,
        colors: game.colors,
        now: game.frameCount,
        back: game.back,
        trail: game.trail,
        felt: game.felt || null,
      });
    },
  });
}
