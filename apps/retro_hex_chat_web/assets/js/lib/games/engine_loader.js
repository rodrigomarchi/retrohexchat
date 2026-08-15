import { GameEngine } from "../game_engine.js";
import { createLocalTransport, normalizeGameTransport } from "./transport.js";

const P2P_ENGINE_LOADERS = {
  hex_pong: () => import("./pong/engine.js").then((module) => module.PongEngine),
  block_breakers: () => import("./breakout/engine.js").then((module) => module.BreakoutEngine),
  light_trails: () => import("./surround/engine.js").then((module) => module.SurroundEngine),
  star_duel: () => import("./star_duel/engine.js").then((module) => module.StarDuelEngine),
  gravity_well: () => import("./star_duel/engine.js").then((module) => module.StarDuelEngine),
  debris_field: () => import("./star_duel/engine.js").then((module) => module.StarDuelEngine),
  hex_warlords: () => import("./warlords/engine.js").then((module) => module.WarlordEngine),
  pixel_tanks: () => import("./pixel_tanks/engine.js").then((module) => module.PixelTanksEngine),
  hex_raid: () => import("./hex_raid/engine.js").then((module) => module.HexRaidEngine),
  hex_raid_pacifist: () => import("./hex_raid/engine.js").then((module) => module.HexRaidEngine),
  hex_raid_blitz: () => import("./hex_raid/engine.js").then((module) => module.HexRaidEngine),
  hex_boxing: () => import("./hex_boxing/engine.js").then((module) => module.BoxingEngine),
  hex_outlaw: () => import("./hex_outlaw/engine.js").then((module) => module.OutlawEngine),
  hex_outlaw_ricochet: () => import("./hex_outlaw/engine.js").then((module) => module.OutlawEngine),
  hex_outlaw_stagecoach: () =>
    import("./hex_outlaw/engine.js").then((module) => module.OutlawEngine),
  hex_outlaw_nml: () => import("./hex_outlaw/engine.js").then((module) => module.OutlawEngine),
  hex_invaders: () => import("./hex_invaders/engine.js").then((module) => module.HexInvadersEngine),
  hex_invaders_coop: () =>
    import("./hex_invaders/engine.js").then((module) => module.HexInvadersEngine),
  hex_invaders_blitz: () =>
    import("./hex_invaders/engine.js").then((module) => module.HexInvadersEngine),
  hex_enduro: () => import("./hex_enduro/engine.js").then((module) => module.HexEnduroEngine),
  hex_enduro_night: () => import("./hex_enduro/engine.js").then((module) => module.HexEnduroEngine),
  hex_enduro_sprint: () =>
    import("./hex_enduro/engine.js").then((module) => module.HexEnduroEngine),
  hex_tennis: () => import("./hex_tennis/engine.js").then((module) => module.TennisEngine),
  hex_tennis_quick: () => import("./hex_tennis/engine.js").then((module) => module.TennisEngine),
  hex_tennis_sudden: () => import("./hex_tennis/engine.js").then((module) => module.TennisEngine),
  hex_skiing: () => import("./hex_skiing/engine.js").then((module) => module.HexSkiingEngine),
  hex_skiing_escape: () =>
    import("./hex_skiing/engine.js").then((module) => module.HexSkiingEngine),
  hex_skiing_clean: () => import("./hex_skiing/engine.js").then((module) => module.HexSkiingEngine),
  hex_frost: () => import("./hex_frost/engine.js").then((module) => module.HexFrostEngine),
  hex_frost_blizzard: () => import("./hex_frost/engine.js").then((module) => module.HexFrostEngine),
  hex_frost_peaceful: () => import("./hex_frost/engine.js").then((module) => module.HexFrostEngine),
  hex_hockey: () => import("./hex_hockey/engine.js").then((module) => module.HexHockeyEngine),
  hex_hockey_blitz: () => import("./hex_hockey/engine.js").then((module) => module.HexHockeyEngine),
  hex_hockey_showdown: () =>
    import("./hex_hockey/engine.js").then((module) => module.HexHockeyEngine),
};

const SOLO_GAME_IDS = new Set([
  "hex_pong",
  "light_trails",
  "star_duel",
  "gravity_well",
  "debris_field",
  "hex_raid",
  "hex_raid_pacifist",
  "hex_raid_blitz",
  "hex_outlaw",
  "hex_outlaw_ricochet",
  "hex_outlaw_stagecoach",
  "hex_outlaw_nml",
  "hex_tennis",
  "hex_tennis_quick",
  "hex_tennis_sudden",
  "hex_invaders",
  "hex_invaders_coop",
  "hex_invaders_blitz",
  "hex_hockey",
  "hex_hockey_blitz",
  "hex_hockey_showdown",
]);

const SOLO_CONTROLLER_LOADERS = {
  hex_raid: () => import("./hex_raid/ai.js").then((module) => module.createHexRaidAI),
  hex_raid_pacifist: () => import("./hex_raid/ai.js").then((module) => module.createHexRaidAI),
  hex_raid_blitz: () => import("./hex_raid/ai.js").then((module) => module.createHexRaidAI),
};

/**
 * @param {string} gameId
 * @returns {boolean}
 */
export function supportsSolo(gameId) {
  return SOLO_GAME_IDS.has(gameId);
}

/**
 * @param {string} gameId
 * @returns {Promise<typeof GameEngine>}
 */
export async function loadP2PEngineClass(gameId) {
  const load = P2P_ENGINE_LOADERS[gameId];
  return load ? load() : GameEngine;
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

async function createSoloOpponentController(gameId, options = {}) {
  const loadController = SOLO_CONTROLLER_LOADERS[gameId];
  if (!loadController) return null;

  const createController = await loadController();
  return createController(options);
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

  const options = {
    ...engineOptions,
    mode: runtimeMode,
  };
  const soloOpponentController =
    solo && !opponentController
      ? await createSoloOpponentController(gameId, { difficulty })
      : opponentController;

  if (soloOpponentController) options.opponentController = soloOpponentController;
  if (difficulty) options.difficulty = difficulty;

  return new EngineClass(canvas, engineTransport, gameId, solo ? true : isHost, onGameEnd, options);
}
