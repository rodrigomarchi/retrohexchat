/**
 * Hex Sudoku: Sudoku in three levels, played with a mouse, a finger or the
 * keyboard — choose a square, then a digit from the keypad; the pencil puts
 * notes, a wrong digit shows red and costs time, a hint reveals a square for
 * a minute. Each grid is made in the page, one solution, its level the
 * hardest technique it needs. A one-player game: no opponent, nothing on the
 * wire.
 *
 * @module games/hex_sudoku
 */

import { defineGame } from "../core/define_game.js";
import { createGesture } from "../core/pointer.js";
import { createRng } from "../core/rng.js";
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
import { createEffects, playedEffects } from "./effects.js";
import { createGeneration } from "./generator.js";
import { KEYS, interpret, keyAction } from "./gestures.js";
import { GEOMETRY, layout } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import { EVENT, LEVEL, TILES_URL } from "./protocol.js";
import { readColors, render } from "./renderer.js";
import { MASTER_VOLUME, SOUNDS } from "./sounds.js";

const EVENT_SOUNDS = eventSounds(EVENT);

/** How long the grid shows a win before its result is told: the light runs from the centre out. */
const SHOW_TICKS = 150;

/** An action played, with what it draws. */
function play(game, action) {
  if (!action) return;
  const before = game.gameState;
  game.gameState = act(before, action, game.random);
  if (game.gameState !== before) drawMoved(game, before, playedEffects);
}

function onPointer(game, event) {
  if (game.gameState.phase !== PHASE.PLAYING) return;
  for (const gesture of game.gesture(event)) play(game, interpret(game.laid, gesture));
}

/** One tick of a match in play: a try at the grid until it is made, the keys pressed, and the clock. */
function tick(game) {
  game.frameCount++;
  if (!game.gameState.board) {
    const grid = game.generation.next();
    if (grid) play(game, { type: "grid", grid });
  }
  const keys = game.keys;
  game.keys = [];
  for (const action of keys) play(game, action);
  endTick(game, { step, sounds: EVENT_SOUNDS });
}

export default defineGame({
  ...boardDefinition({
    sounds: SOUNDS,
    masterVolume: MASTER_VOLUME,
    theme: readColors,
    finalScore,
  }),
  captureKeys: KEYS,
  setup: (game) => {
    game.frameCount = 0;
    game.fx = createEffects({ reduced: reducedMotion() });
    game.gesture = createGesture({ slop: TAP_SLOP });
    game.keys = [];
    loadAtlas(game, TILES_URL, "HexSudoku");
  },
  // A phone held upright stands the table up: the keypad under the grid.
  view: tableView(GEOMETRY),
  init: (game) => {
    game.laid = layout(laidFor(GEOMETRY, game.view));
    // The grid draws from a stream of its own: the same seed, the same grid.
    const spec = LEVEL[game.gameId] ?? LEVEL.hex_sudoku;
    game.generation = createGeneration(spec, createRng(game.matchSeed).fork("grid").next);
    return createInitialState();
  },
  onPointer,
  // A key is played in the tick, in order with the taps, so a match replays the same.
  onKeyDown: (game, event) => {
    const action = keyAction(event.key);
    if (action && game.gameState.phase === PHASE.PLAYING) game.keys.push(action);
  },
  // The grid lighting up, before the result.
  flow: boardFlow({ tick, sounds: EVENT_SOUNDS, showTicks: () => SHOW_TICKS, finalScore }),
  render: (game) => render(game.ctx, boardScene(game)),
});
