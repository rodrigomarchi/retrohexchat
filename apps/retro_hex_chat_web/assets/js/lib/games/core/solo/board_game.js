/**
 * What a one-player board game drawn from an atlas shares with every other —
 * Hex Mines and Hex Sudoku: the definition's fixed parts (one player, the
 * pointer, pixel art at twice the pixels, its sounds and colours, the score as
 * it stands), the atlas loaded in the background, the end of a tick in play
 * (the sounds of its events, the match's step, the effects, a frame when
 * something moved or the clock's second turned), and the flow from play to
 * the board shown as the match ended, to its result.
 *
 * @module games/core/solo/board_game
 */

import { log } from "../../../logger.js";
import { browserAtlasIO, createAtlasLoader } from "../atlas.js";
import { playFlags } from "../events.js";
import { soloResult } from "../result.js";
import { active, stepEffects } from "./effects.js";
import { PHASE } from "./phases.js";

/** The sound of each event bit, by the event's name: `EVENT.BOOM` plays `boom`. */
export const eventSounds = (EVENT) =>
  Object.entries(EVENT).map(([name, bit]) => [bit, name.toLowerCase()]);

/**
 * The parts of a definition every board game has the same: spread into
 * `defineGame({ ... })`.
 * @param {{ sounds: object, masterVolume: number, theme: Function,
 *   finalScore: (state: object) => number }} game
 */
export const boardDefinition = ({ sounds, masterVolume, theme, finalScore }) => ({
  players: 1,
  pointer: true,
  pixelArt: true,
  resolution: 2,
  inputs: {},
  audio: { sounds, masterVolume },
  theme,
  standing: (game) => soloResult(finalScore(game.gameState)),
});

/** The game's atlas, fetched in the background: `game.atlas` once it is here, a frame drawn. */
export function loadAtlas(game, url, name) {
  game.atlas = null;
  createAtlasLoader(browserAtlasIO)(url)
    .then((atlas) => {
      game.atlas = atlas;
      game.invalidate();
    })
    .catch((error) => log.warn(`[${name}] the tiles did not load`, error));
}

/** The sounds of how a match ended, played once: its events are cleared, and a frame drawn. */
export function soundTheEnd(game, sounds) {
  playFlags(game, sounds, game.gameState.events);
  game.gameState = { ...game.gameState, events: 0 };
  game.invalidate();
}

/**
 * The end of a tick in play, once its actions are played: their sounds, the
 * match's `step`, the effects, and a frame when anything moved or the clock
 * turned a second.
 */
export function endTick(game, { step, sounds }) {
  const second = Math.floor(game.gameState.clock.ticks / 60);
  playFlags(game, sounds, game.gameState.events);
  game.gameState = step(game.gameState);
  const moving = active(game.fx);
  stepEffects(game.fx, game.frameCount);
  if (moving || Math.floor(game.gameState.clock.ticks / 60) !== second) game.invalidate();
}

/**
 * The flow of a board game: in play (`tick`), then the board shown as the
 * match ended for `showTicks(state)` ticks, then the result.
 * @param {{ tick: Function, sounds: Array, showTicks: (state: object) => number,
 *   finalScore: (state: object) => number, onShow?: (game: object) => void }} flow
 */
export const boardFlow = ({ tick, sounds, showTicks, finalScore, onShow = () => {} }) => ({
  phases: PHASE,
  initial: "WAITING",
  begin: "PLAYING",
  states: {
    PLAYING: { tick },
    CELEBRATING: {
      enter: (game) => {
        onShow(game);
        game.shown = 0;
        soundTheEnd(game, sounds);
      },
      tick: (game) => {
        game.frameCount++;
        game.shown++;
        stepEffects(game.fx, game.frameCount);
        game.invalidate();
        if (game.shown >= showTicks(game.gameState)) {
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
});

/** What a board game's picture is drawn from: the match, the layout, the effects, the atlas, the colours, the frame. */
export const boardScene = (game) => ({
  state: game.gameState,
  laid: game.laid,
  fx: game.fx,
  atlas: game.atlas,
  colors: game.colors,
  now: game.frameCount,
});
