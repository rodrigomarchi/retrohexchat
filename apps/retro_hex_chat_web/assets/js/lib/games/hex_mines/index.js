/**
 * Hex Mines: Minesweeper in three levels, played with a mouse or a finger —
 * a right click or a long press plants a flag, a tap on a number opens around
 * it, and a phone has a switch to flag with a tap. A one-player game: no
 * opponent, nothing on the wire.
 *
 * @module games/hex_mines
 */

import { log } from "../../logger.js";
import { browserAtlasIO, createAtlasLoader } from "../core/atlas.js";
import { defineGame } from "../core/define_game.js";
import { playFlags } from "../core/events.js";
import { createGesture } from "../core/pointer.js";
import { soloResult } from "../core/result.js";
import { PHASE, TAP_SLOP } from "../core/solo/phases.js";
import { laidFor, tableView } from "../core/solo/view.js";
import { active, boardEffects, createEffects, stepEffects } from "./effects.js";
import { interpret } from "./gestures.js";
import { cellAt, geometryFor, layout } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import { EVENT, HOLD_TICKS, LEVEL, TILES_URL } from "./protocol.js";
import { readColors, render } from "./renderer.js";
import { CELL } from "./rules.js";
import { MASTER_VOLUME, SOUNDS } from "./sounds.js";

/** The sound of each event bit, by the event's name: `BOOM` plays `boom`. */
const EVENT_SOUNDS = Object.entries(EVENT).map(([name, bit]) => [bit, name.toLowerCase()]);

/** How long the board shows how the match ended before its result is told: a win's flags all light. */
const SHOW_TICKS = Object.freeze({ lost: 90, won: 150 });

const reducedMotion = () =>
  globalThis.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true;

const levelOf = (game) => LEVEL[game.gameId] ?? LEVEL.hex_mines;

/** An action from the board, played, with what it draws. */
function play(game, action) {
  if (!action) return;
  const before = game.gameState;
  game.gameState = act(before, action, game.random);
  boardEffects(game.fx, {
    before,
    after: game.gameState,
    laid: game.laid,
    now: game.frameCount,
    random: game.fxRandom,
  });
  // A flag planted with a long press: a short buzz where the phone allows it.
  if (action.type === "flag" && action.held) globalThis.navigator?.vibrate?.(15);
  game.invalidate();
}

/** The square a press is held on, shown pressed while it is. */
function press(game, event) {
  const i = event.type === "down" ? cellAt(game.laid, event.x, event.y) : null;
  const shut = i !== null && game.gameState.board.cell[i] === CELL.CLOSED;
  const pressed = shut && event.button !== "secondary" ? i : null;
  if (pressed !== game.pressed) {
    game.pressed = pressed;
    game.invalidate();
  }
}

function onPointer(game, event) {
  if (game.gameState.phase !== PHASE.PLAYING) return;
  if (event.type === "down" || event.type === "up" || event.type === "cancel") press(game, event);
  // A finger's long press flags; a mouse has its right button for that.
  for (const gesture of game.gesture({ ...event, hold: event.device !== "mouse" })) {
    if (gesture.type === "dragStart") press(game, { type: "cancel" });
    const action = interpret(game.gameState, game.laid, gesture);
    play(game, action && { ...action, held: gesture.type === "hold" });
  }
}

/** One tick of a match in play: a long press may come due, and the clock runs. */
function tick(game) {
  game.frameCount++;
  for (const gesture of game.gesture.tick()) {
    press(game, { type: "cancel" });
    const action = interpret(game.gameState, game.laid, gesture);
    play(game, action && { ...action, held: true });
  }
  const second = Math.floor(game.gameState.clock.ticks / 60);
  playFlags(game, EVENT_SOUNDS, game.gameState.events);
  game.gameState = step(game.gameState);
  const moving = active(game.fx);
  stepEffects(game.fx, game.frameCount);
  if (moving || Math.floor(game.gameState.clock.ticks / 60) !== second) game.invalidate();
}

export default defineGame({
  players: 1,
  pointer: true,
  pointerButtons: ["main", "secondary"],
  pixelArt: true,
  resolution: 2,
  inputs: {},
  audio: { sounds: SOUNDS, masterVolume: MASTER_VOLUME },
  theme: readColors,
  setup: (game) => {
    game.frameCount = 0;
    game.fx = createEffects({ reduced: reducedMotion() });
    game.gesture = createGesture({ slop: TAP_SLOP, holdTicks: HOLD_TICKS });
    game.pressed = null;
    game.atlas = null;
    createAtlasLoader(browserAtlasIO)(TILES_URL)
      .then((atlas) => {
        game.atlas = atlas;
        game.invalidate();
      })
      .catch((error) => log.warn("[HexMines] the tiles did not load", error));
  },
  // A phone held upright stands the board up; the expert board turns.
  view: tableView(geometryFor),
  init: (game) => {
    game.laid = layout(levelOf(game), laidFor(geometryFor(game.gameId), game.view));
    return createInitialState(levelOf(game));
  },
  onPointer,
  flow: {
    phases: PHASE,
    initial: "WAITING",
    begin: "PLAYING",
    states: {
      PLAYING: { tick },
      // The board as the match ended — the mine gone off, or the flags of a win — before the result.
      CELEBRATING: {
        enter: (game) => {
          game.pressed = null;
          game.shown = 0;
          playFlags(game, EVENT_SOUNDS, game.gameState.events);
          game.gameState = { ...game.gameState, events: 0 };
          game.invalidate();
        },
        tick: (game) => {
          game.frameCount++;
          game.shown++;
          stepEffects(game.fx, game.frameCount);
          game.invalidate();
          if (game.shown >= (game.gameState.won ? SHOW_TICKS.won : SHOW_TICKS.lost)) {
            game.gameState = { ...game.gameState, phase: PHASE.FINISHED };
          }
        },
      },
      FINISHED: {
        final: true,
        enter: (game) => {
          game.invalidate();
          game.finish({ result: soloResult(finalScore(game.gameState)) });
        },
      },
    },
  },
  standing: (game) => soloResult(finalScore(game.gameState)),
  render: (game) =>
    render(game.ctx, {
      state: game.gameState,
      laid: game.laid,
      fx: game.fx,
      atlas: game.atlas,
      colors: game.colors,
      now: game.frameCount,
      pressed: game.pressed,
    }),
});
