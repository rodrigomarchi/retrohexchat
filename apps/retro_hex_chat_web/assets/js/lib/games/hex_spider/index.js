/**
 * Hex Spider: two decks in ten columns, in one suit, two or four, played with
 * a mouse or a finger. A one-player game: no opponent, nothing on the wire.
 *
 * The match around the table comes from the card table (`core/card_table/table.js`);
 * this file says only what is Spider's.
 *
 * @module games/hex_spider
 */

import { defineCardTable } from "../core/card_table/table.js";
import { actionEffects, autoMove, cascadeEffects, dealEffects } from "./effects.js";
import { interpret } from "./gestures.js";
import { hitTest } from "./layout.js";
import { act, createInitialState, finalScore, step } from "./physics.js";
import { EVENT, GEOMETRY, SUITS_BY_GAME } from "./protocol.js";
import { render } from "./renderer.js";

export default defineCardTable({
  name: "HexSpider",
  events: EVENT,
  geometry: GEOMETRY,
  init: (game, geometry) =>
    createInitialState(game.random, SUITS_BY_GAME[game.gameId] ?? 1, geometry),
  act,
  step,
  finalScore,
  interpret,
  hitTest,
  // While waiting, a tap on the stock turns its back.
  backTap: (table, hit) => hit?.pile === "stock",
  effects: { deal: dealEffects, action: actionEffects, cascade: cascadeEffects, auto: autoMove },
  render,
});
