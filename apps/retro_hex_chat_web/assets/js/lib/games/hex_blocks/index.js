/**
 * Hex Blocks: falling hexagons in a honeycomb well — move, turn and drop the
 * pieces of four hexagons as they fall, and clear a zigzag row by filling
 * it. The Marathon speeds up every ten rows until the stack tops out; the
 * Sprint is forty rows against the clock. Played with keys: the keyboard's,
 * or the pad's under the game on a phone. A one-player game: no opponent,
 * nothing on the wire.
 *
 * @module games/hex_blocks
 */

import { defineGame } from "../core/define_game.js";
import { createRng } from "../core/rng.js";
import {
  boardDefinition,
  boardFlow,
  boardScene,
  drawMoved,
  endTick,
  eventSounds,
  playKeys,
  queueKey,
} from "../core/solo/board_game.js";
import { PHASE } from "../core/solo/phases.js";
import { laidFor, tableView } from "../core/solo/view.js";
import { FX, playedEffects } from "./effects.js";
import { KEYS, keyDown, keyUp } from "./gestures.js";
import { GEOMETRY, layout } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import { EVENT, MODE, TILES_URL } from "./protocol.js";
import { readColors, render } from "./renderer.js";
import { MASTER_VOLUME, SOUNDS } from "./sounds.js";

const EVENT_SOUNDS = eventSounds(EVENT);

/** How long the well shows the end before its result is told. */
const showTicks = (state) => (state.won ? 150 : FX.fade + 30);

/** The match moved from `before`: what it draws, when anything changed. */
function drawn(game, before) {
  if (game.gameState !== before) drawMoved(game, before, playedEffects);
}

/** An action played. */
function play(game, action) {
  if (!action) return;
  const before = game.gameState;
  game.gameState = act(before, action, game.bag);
  drawn(game, before);
}

/** One tick of a match in play: the keys pressed, then the count, the moves held, gravity and the clock. */
function tick(game) {
  game.frameCount++;
  playKeys(game, play);
  const before = { ...game.gameState, events: 0 };
  endTick(game, { step: (state) => step(state, game.bag), sounds: EVENT_SOUNDS });
  drawn(game, before);
}

/** Every move held down let go: the window lost the keyboard. */
const RELEASE_ALL = ["left", "right", "down"].map((input) => ({ type: "release", input }));

export default defineGame({
  ...boardDefinition({
    name: "HexBlocks",
    tilesUrl: TILES_URL,
    sounds: SOUNDS,
    masterVolume: MASTER_VOLUME,
    theme: readColors,
    finalScore,
    setup: (game) => {
      game.keys = [];
    },
  }),
  // Played with keys only: nothing on the canvas takes a press.
  pointer: false,
  captureKeys: KEYS,
  // A phone held upright stands the table up.
  view: tableView(GEOMETRY),
  init: (game) => {
    game.laid = layout(laidFor(GEOMETRY, game.view));
    // The pieces come from a stream of their own: the same seed, the same pieces.
    game.bag = createRng(game.matchSeed).fork("bag").next;
    return createInitialState(MODE[game.gameId] ?? MODE.hex_blocks, game.bag);
  },
  // A key is played in the tick, in order, so a match replays the same.
  onKeyDown: (game, event) => queueKey(game, keyDown(event)),
  onKeyUp: (game, event) => queueKey(game, keyUp(event)),
  onBlur: (game) => {
    if (game.gameState?.phase === PHASE.PLAYING) game.keys.push(...RELEASE_ALL);
  },
  // The end shown — the well going dark, or the Sprint's sparks — before the result.
  flow: boardFlow({ tick, sounds: EVENT_SOUNDS, showTicks, finalScore }),
  render: (game) => render(game.ctx, boardScene(game)),
});
