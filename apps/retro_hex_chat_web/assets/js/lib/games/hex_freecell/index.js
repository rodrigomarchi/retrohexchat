/**
 * Hex FreeCell: the whole deck face up, four free cells to work with, played
 * with a mouse or a finger. A one-player game: no opponent, nothing on the wire.
 *
 * The match around the table comes from the card table (`core/card_table/table.js`);
 * this file says only what is FreeCell's.
 *
 * @module games/hex_freecell
 */

import { defineCardTable } from "../core/card_table/table.js";
import { actionEffects, autoMove, cascadeEffects, dealEffects } from "./effects.js";
import { interpret } from "./gestures.js";
import { hitTest } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import { EVENT, GEOMETRY } from "./protocol.js";
import { render } from "./renderer.js";

export default defineCardTable({
  name: "HexFreeCell",
  events: EVENT,
  geometry: GEOMETRY,
  init: (game, geometry) => createInitialState(game.random, geometry),
  act,
  step,
  finalScore,
  interpret,
  hitTest,
  effects: { deal: dealEffects, action: actionEffects, cascade: cascadeEffects, auto: autoMove },
  render,
});
