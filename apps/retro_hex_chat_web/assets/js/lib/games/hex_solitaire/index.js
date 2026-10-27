/**
 * Hex Solitaire: Klondike, drawing one card or three, played with a mouse or
 * a finger. A one-player game: no opponent, nothing on the wire.
 *
 * The match lifecycle comes from `defineGame`; this file says only what is
 * the table's — its gestures, its phases, its effects and what each one draws.
 *
 * @module games/hex_solitaire
 */

import { log } from "../../logger.js";
import { CARD_ATLAS_URL, browserCardAtlasLoader } from "../core/cards.js";
import { createLayer } from "../core/layers.js";
import { defineGame } from "../core/define_game.js";
import { playFlags } from "../core/events.js";
import { createGesture } from "../core/pointer.js";
import { soloResult } from "../core/result.js";
import {
  actionEffects,
  active,
  cascadeEffects,
  createEffects,
  dealEffects,
  settle,
  stepEffects,
} from "./effects.js";
import { interpret } from "./gestures.js";
import { hitTest } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import {
  CELEBRATION_TICKS,
  EVENT,
  GEOMETRY,
  MODE,
  MODE_BY_GAME,
  PHASE,
  TAP_SLOP,
} from "./protocol.js";
import { feltWeave, readColors, render } from "./renderer.js";
import { MASTER_VOLUME, SOUNDS } from "./sounds.js";

/** The sound of each event bit. */
const EVENT_SOUNDS = [
  [EVENT.DEAL, "deal"],
  [EVENT.DRAW, "draw"],
  [EVENT.FLIP, "flip"],
  [EVENT.PLACE, "place"],
  [EVENT.FOUNDATION, "foundation"],
  [EVENT.REFUSE, "refuse"],
  [EVENT.RECYCLE, "recycle"],
  [EVENT.RETURN, "return"],
  [EVENT.WIN, "win"],
];

/** The back a player last chose, kept by the browser for every card game. */
const BACK_KEY = "retrohex.cards.back";
const BACKS = 4;

function storedBack() {
  try {
    const back = Number(globalThis.localStorage?.getItem(BACK_KEY));
    return Number.isInteger(back) && back >= 0 && back < BACKS ? back : 0;
  } catch (error) {
    log.debug("[HexSolitaire] the chosen back could not be read", error);
    return 0;
  }
}

function storeBack(back) {
  try {
    globalThis.localStorage?.setItem(BACK_KEY, String(back));
  } catch (error) {
    log.debug("[HexSolitaire] the chosen back could not be kept", error);
  }
}

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

const reducedMotion = () =>
  globalThis.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true;

/** An action from the table, played, with the effects it draws. */
function play(game, action) {
  if (!action) return;
  const before = game.gameState;
  const after = act(before, action);
  game.gameState = after;
  actionEffects(game.fx, {
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

/** What a press does: in play, a tap or a drag on the table; while waiting, a tap on the stock turns its back. */
function onPointer(game, event) {
  const s = game.gameState;
  for (const gesture of game.gesture(event)) {
    if (s.phase === PHASE.WAITING) {
      if (gesture.type === "tap" && hitTest(s.table, gesture.x, gesture.y)?.pile === "stock") {
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
    const { drag, action } = interpret(game.gameState.table, game.drag, gesture);
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
  game.gameState = step(game.gameState);
  const finished = game.gameState.events;
  if (game.gameState.table !== before) {
    actionEffects(game.fx, {
      before,
      after: game.gameState.table,
      action: { type: "move", move: lastAutoMove(before, game.gameState.table) },
      events: finished,
      now: game.frameCount,
      random: game.fxRandom,
    });
  }
  playFlags(game, EVENT_SOUNDS, events | finished);
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

/** The card the finish sent up between two tables, as a move. */
function lastAutoMove(before, after) {
  const suit = after.foundations.findIndex((pile, i) => pile.length > before.foundations[i].length);
  const card = after.foundations[suit].at(-1);
  const col = before.tableau.findIndex((column) => column.up.at(-1) === card);
  return {
    from: { pile: "tableau", col, index: before.tableau[col].up.length - 1 },
    to: { pile: "foundation", suit },
  };
}

export default defineGame({
  players: 1,
  pointer: true,
  pixelArt: true,
  resolution: 2,
  inputs: {},
  audio: { sounds: SOUNDS, masterVolume: MASTER_VOLUME },
  theme: readColors,
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
      .catch((error) => log.warn("[HexSolitaire] the card atlas did not load", error));
  },
  // A phone held upright gives the canvas a box taller than wide: the table
  // stands up in it, so the cards are as big as the phone allows.
  view: (canvas) => {
    const box = canvas.getBoundingClientRect();
    return box.height > box.width ? GEOMETRY.PORTRAIT.view : GEOMETRY.LANDSCAPE.view;
  },
  init: (game) =>
    createInitialState(
      game.random,
      MODE_BY_GAME[game.gameId] ?? MODE.DRAW1,
      game.view.height > game.view.width ? GEOMETRY.PORTRAIT : GEOMETRY.LANDSCAPE,
    ),
  onPointer,
  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "PLAYING",
    states: {
      PLAYING: {
        enter: (game) => {
          dealEffects(game.fx, game.gameState.table, game.frameCount);
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
          cascadeEffects(game.fx, game.gameState.table, game.frameCount, game.fxRandom);
          playFlags(game, EVENT_SOUNDS, game.gameState.events);
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
          playFlags(game, EVENT_SOUNDS, game.gameState.events);
          game.invalidate();
          game.finish({ result: soloResult(finalScore(game.gameState)) });
        },
      },
    },
  },
  // A match ended mid-celebration keeps the bonus its win earned.
  standing: (game) => soloResult(finalScore(game.gameState)),
  render: (game) => {
    // Made once the colours are read; false where the page cannot make one.
    game.felt ??= feltWeave(game.ctx, game.colors, game.canvas.ownerDocument) ?? false;
    return render(game.ctx, {
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
