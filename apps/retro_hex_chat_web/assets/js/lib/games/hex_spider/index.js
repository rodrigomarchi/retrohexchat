/**
 * Hex Spider: two decks in ten columns, in one suit, two or four, played with
 * a mouse or a finger. A one-player game: no opponent, nothing on the wire.
 *
 * The match around the table comes from the card table (`core/card_table/table.js`);
 * this file says only what is Spider's.
 *
 * @module games/hex_spider
 */

// ex_dna:disable-for-lines:7 this game's own modules, handed to the card table
import { defineCardTable } from "../core/card_table/table.js";
import * as effects from "./effects.js";
import { interpret } from "./gestures.js";
import { hitTest } from "./layout.js";
import * as match from "./physics.js";
import { GEOMETRY, SUITS_BY_GAME } from "./protocol.js";
import { render } from "./renderer.js";

export default defineCardTable({
  name: "HexSpider",
  geometry: GEOMETRY,
  init: (game, geometry) =>
    match.createInitialState(game.random, SUITS_BY_GAME[game.gameId] ?? 1, geometry),
  match,
  effects,
  interpret,
  hitTest,
  // While waiting, a tap on the stock turns its back.
  backTap: (table, hit) => hit?.pile === "stock",
  render,
});
