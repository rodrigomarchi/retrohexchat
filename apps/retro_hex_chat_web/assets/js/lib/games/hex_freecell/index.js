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
import * as effects from "./effects.js";
import { interpret } from "./gestures.js";
import { hitTest } from "./layout.js";
import * as match from "./physics.js";
import { GEOMETRY } from "./protocol.js";
import { render } from "./renderer.js";

export default defineCardTable({
  name: "HexFreeCell",
  geometry: GEOMETRY,
  init: (game, geometry) => match.createInitialState(game.random, geometry),
  match,
  effects,
  interpret,
  hitTest,
  render,
});
