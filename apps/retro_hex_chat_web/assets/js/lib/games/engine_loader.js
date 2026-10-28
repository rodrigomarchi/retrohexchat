import { GameEngine } from "../game_engine.js";
import { aiRandom, freshSeed } from "./core/rng.js";
import { createLocalTransport, normalizeGameTransport } from "./transport.js";
import REGISTRY from "./registry.json";

// One literal import per folder: esbuild splits a chunk only for an import
// whose path it can read. The registry says which folder each game id is in.
const DEFINITION_LOADERS = {
  breakout: () => import("./breakout/index.js"),
  hex_boxing: () => import("./hex_boxing/index.js"),
  hex_enduro: () => import("./hex_enduro/index.js"),
  hex_frost: () => import("./hex_frost/index.js"),
  hex_hockey: () => import("./hex_hockey/index.js"),
  hex_freecell: () => import("./hex_freecell/index.js"),
  hex_invaders: () => import("./hex_invaders/index.js"),
  hex_jungle: () => import("./hex_jungle/index.js"),
  hex_mines: () => import("./hex_mines/index.js"),
  hex_sudoku: () => import("./hex_sudoku/index.js"),
  hex_blocks: () => import("./hex_blocks/index.js"),
  hex_solitaire: () => import("./hex_solitaire/index.js"),
  hex_spider: () => import("./hex_spider/index.js"),
  hex_outlaw: () => import("./hex_outlaw/index.js"),
  hex_raid: () => import("./hex_raid/index.js"),
  hex_skiing: () => import("./hex_skiing/index.js"),
  hex_tennis: () => import("./hex_tennis/index.js"),
  pixel_tanks: () => import("./pixel_tanks/index.js"),
  pong: () => import("./pong/index.js"),
  star_duel: () => import("./star_duel/index.js"),
  surround: () => import("./surround/index.js"),
  warlords: () => import("./warlords/index.js"),
};

// Raid, Enduro and Skiing keep their AI out of the game's chunk: it is
// downloaded only for a solo match. Every other game's definition makes its own.
const SOLO_AI_LOADERS = {
  hex_enduro: () => import("./hex_enduro/ai.js").then((module) => module.createHexEnduroAI),
  hex_raid: () => import("./hex_raid/ai.js").then((module) => module.createHexRaidAI),
  hex_skiing: () => import("./hex_skiing/ai.js").then((module) => module.createHexSkiingAI),
};

/**
 * @param {string} gameId
 * @returns {boolean}
 */
export function supportsSolo(gameId) {
  return Object.hasOwn(REGISTRY, gameId) && REGISTRY[gameId].solo;
}

/**
 * @param {string} gameId
 * @returns {Promise<typeof GameEngine>}
 */
export async function loadP2PEngineClass(gameId) {
  if (!Object.hasOwn(REGISTRY, gameId)) return GameEngine;
  return DEFINITION_LOADERS[REGISTRY[gameId].dir]().then((module) => module.default);
}

/**
 * @param {string} gameId
 * @returns {Promise<typeof GameEngine>}
 */
export async function loadSoloEngineClass(gameId) {
  if (!supportsSolo(gameId)) {
    throw new Error(`Game ${gameId} does not support solo mode`);
  }

  return loadP2PEngineClass(gameId);
}

/**
 * @param {object} options
 * @param {HTMLCanvasElement} options.canvas
 * @param {string} options.gameId
 * @param {"p2p_host"|"p2p_guest"|"solo"} [options.mode]
 * @param {object} [options.transport]
 * @param {RTCDataChannel} [options.channel]
 * @param {boolean} [options.isHost]
 * @param {function|null} [options.onGameEnd]
 * @param {object} [options.engineOptions]
 * @param {object} [options.opponentController]
 * @param {string} [options.difficulty]
 * @returns {Promise<GameEngine>}
 */
export async function createGameEngine({
  canvas,
  gameId,
  mode,
  transport,
  channel,
  isHost = false,
  onGameEnd = null,
  engineOptions = {},
  opponentController,
  difficulty,
}) {
  const runtimeMode = mode || (isHost ? "p2p_host" : "p2p_guest");
  const solo = runtimeMode === "solo";
  const EngineClass = solo ? await loadSoloEngineClass(gameId) : await loadP2PEngineClass(gameId);
  const engineTransport = transport
    ? normalizeGameTransport(transport)
    : solo
      ? createLocalTransport()
      : normalizeGameTransport(channel);

  // A solo match's opponent draws from the match seed's AI stream: made by
  // the game's definition, or — for an AI kept out of the game's chunk —
  // loaded and made here.
  const options = {
    ...engineOptions,
    mode: runtimeMode,
    seed: engineOptions.seed ?? freshSeed(),
  };
  const soloOpponentController =
    solo && !opponentController && SOLO_AI_LOADERS[REGISTRY[gameId]?.dir]
      ? (await SOLO_AI_LOADERS[REGISTRY[gameId].dir]())({ difficulty, rng: aiRandom(options.seed) })
      : opponentController;
  if (soloOpponentController) options.opponentController = soloOpponentController;
  if (difficulty) options.difficulty = difficulty;

  return new EngineClass(canvas, engineTransport, gameId, solo ? true : isHost, onGameEnd, options);
}
