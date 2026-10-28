/**
 * Hex Mines: Minesweeper in three levels, played with a mouse or a finger —
 * a right click or a long press plants a flag, a tap on a number opens around
 * it, and a phone has a switch to flag with a tap. A one-player game: no
 * opponent, nothing on the wire.
 *
 * @module games/hex_mines
 */

import { defineGame } from "../core/define_game.js";
import { createGesture } from "../core/pointer.js";
import {
  boardDefinition,
  boardFlow,
  boardScene,
  drawMoved,
  endTick,
  eventSounds,
  loadAtlas,
  reducedMotion,
} from "../core/solo/board_game.js";
import { PHASE, TAP_SLOP } from "../core/solo/phases.js";
import { laidFor, tableView } from "../core/solo/view.js";
import { boardEffects, createEffects } from "./effects.js";
import { interpret } from "./gestures.js";
import { cellAt, geometryFor, layout } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import { EVENT, HOLD_TICKS, LEVEL, TILES_URL } from "./protocol.js";
import { readColors, render } from "./renderer.js";
import { CELL } from "./rules.js";
import { MASTER_VOLUME, SOUNDS } from "./sounds.js";

const EVENT_SOUNDS = eventSounds(EVENT);

/** How long the board shows how the match ended before its result is told: a win's flags all light. */
const SHOW_TICKS = Object.freeze({ lost: 90, won: 150 });

const levelOf = (game) => LEVEL[game.gameId] ?? LEVEL.hex_mines;

/** An action from the board, played, with what it draws. */
function play(game, action) {
  if (!action) return;
  const before = game.gameState;
  game.gameState = act(before, action, game.random);
  drawMoved(game, before, boardEffects);
  // A flag planted with a long press: a short buzz where the phone allows it.
  if (action.type === "flag" && action.held) globalThis.navigator?.vibrate?.(15);
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
  endTick(game, { step, sounds: EVENT_SOUNDS });
}

export default defineGame({
  ...boardDefinition({
    sounds: SOUNDS,
    masterVolume: MASTER_VOLUME,
    theme: readColors,
    finalScore,
  }),
  pointerButtons: ["main", "secondary"],
  setup: (game) => {
    game.frameCount = 0;
    game.fx = createEffects({ reduced: reducedMotion() });
    game.gesture = createGesture({ slop: TAP_SLOP, holdTicks: HOLD_TICKS });
    game.pressed = null;
    loadAtlas(game, TILES_URL, "HexMines");
  },
  // A phone held upright stands the board up; the expert board turns.
  view: tableView(geometryFor),
  init: (game) => {
    game.laid = layout(levelOf(game), laidFor(geometryFor(game.gameId), game.view));
    return createInitialState(levelOf(game));
  },
  onPointer,
  // The board as the match ended — the mine gone off, or the flags of a win — before the result.
  flow: boardFlow({
    tick,
    sounds: EVENT_SOUNDS,
    showTicks: (state) => (state.won ? SHOW_TICKS.won : SHOW_TICKS.lost),
    finalScore,
    onShow: (game) => {
      game.pressed = null;
    },
  }),
  render: (game) => render(game.ctx, { ...boardScene(game), pressed: game.pressed }),
});
