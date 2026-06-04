/**
 * LiveView Hook: GameCanvasHook
 *
 * Wires the game canvas to the GameEngine via the WebRTC DataChannel.
 * Listens for the game_channel_ready event from GameWebRTCHook.
 */
import { GameEngine } from "../../lib/game_engine.js";

/**
 * Load the appropriate engine class for the given game ID.
 * Game engines are intentionally imported lazily so the chat shell does not
 * download every arcade implementation before a game starts.
 *
 * @param {string} gameId
 * @returns {Promise<typeof GameEngine>}
 */
async function loadEngineClass(gameId) {
  switch (gameId) {
    case "hex_pong":
      return import("../../lib/games/pong/engine.js").then((module) => module.PongEngine);
    case "block_breakers":
      return import("../../lib/games/breakout/engine.js").then((module) => module.BreakoutEngine);
    case "light_trails":
      return import("../../lib/games/surround/engine.js").then((module) => module.SurroundEngine);
    case "star_duel":
    case "gravity_well":
    case "debris_field":
      return import("../../lib/games/star_duel/engine.js").then((module) => module.StarDuelEngine);
    case "hex_warlords":
      return import("../../lib/games/warlords/engine.js").then((module) => module.WarlordEngine);
    case "pixel_tanks":
      return import("../../lib/games/pixel_tanks/engine.js").then(
        (module) => module.PixelTanksEngine,
      );
    case "hex_raid":
    case "hex_raid_pacifist":
    case "hex_raid_blitz":
      return import("../../lib/games/hex_raid/engine.js").then((module) => module.HexRaidEngine);
    case "hex_boxing":
      return import("../../lib/games/hex_boxing/engine.js").then((module) => module.BoxingEngine);
    case "hex_outlaw":
    case "hex_outlaw_ricochet":
    case "hex_outlaw_stagecoach":
    case "hex_outlaw_nml":
      return import("../../lib/games/hex_outlaw/engine.js").then((module) => module.OutlawEngine);
    case "hex_invaders":
    case "hex_invaders_coop":
    case "hex_invaders_blitz":
      return import("../../lib/games/hex_invaders/engine.js").then(
        (module) => module.HexInvadersEngine,
      );
    case "hex_enduro":
    case "hex_enduro_night":
    case "hex_enduro_sprint":
      return import("../../lib/games/hex_enduro/engine.js").then(
        (module) => module.HexEnduroEngine,
      );
    case "hex_tennis":
    case "hex_tennis_quick":
    case "hex_tennis_sudden":
      return import("../../lib/games/hex_tennis/engine.js").then((module) => module.TennisEngine);
    case "hex_skiing":
    case "hex_skiing_escape":
    case "hex_skiing_clean":
      return import("../../lib/games/hex_skiing/engine.js").then(
        (module) => module.HexSkiingEngine,
      );
    case "hex_frost":
    case "hex_frost_blizzard":
    case "hex_frost_peaceful":
      return import("../../lib/games/hex_frost/engine.js").then((module) => module.HexFrostEngine);
    case "hex_hockey":
    case "hex_hockey_blitz":
    case "hex_hockey_showdown":
      return import("../../lib/games/hex_hockey/engine.js").then(
        (module) => module.HexHockeyEngine,
      );
    default:
      return GameEngine;
  }
}

/**
 * Create the appropriate engine for the given game ID.
 * @param {HTMLCanvasElement} canvas
 * @param {RTCDataChannel} channel
 * @param {string} gameId
 * @param {boolean} isHost
 * @param {function|null} onGameEnd
 * @returns {Promise<GameEngine>}
 */
async function createEngine(canvas, channel, gameId, isHost, onGameEnd) {
  const EngineClass = await loadEngineClass(gameId);
  return new EngineClass(canvas, channel, gameId, isHost, onGameEnd);
}

const GameCanvasHook = {
  mounted() {
    this.engine = null;
    this.channel = null;
    this._engineLoadToken = null;
    this._engineLoading = false;
    this._gameId = this.el.dataset.gameId || null;
    this._isHost = this.el.dataset.isHost === "true";

    const webrtcEl = document.getElementById("game-webrtc");
    if (webrtcEl) {
      webrtcEl.addEventListener("game_channel_ready", (e) => {
        this.channel = e.detail.channel;
        this._maybeInitGame();
      });

      // Channel may already be ready
      if (webrtcEl._gameDataChannel) {
        this.channel = webrtcEl._gameDataChannel;
        this._maybeInitGame();
      }
    }

    this.handleEvent("game_start", ({ game_id, is_host }) => {
      this._gameId = game_id;
      this._isHost = is_host;
      this._maybeInitGame();
    });

    this.handleEvent("game_end", () => {
      this._cleanup();
    });

    this.pushEvent("game_canvas_ready", {});
  },

  async _maybeInitGame() {
    if (!this._gameId || !this.channel || this.engine || this._engineLoading) return;

    const canvas = this.el.querySelector("canvas");
    if (!canvas) return;

    const isHost = !!this._isHost;
    const onGameEnd = (result) => {
      this.pushEvent("game_result", result);
    };
    const loadToken = {};
    this._engineLoadToken = loadToken;
    this._engineLoading = true;

    let engine;

    try {
      engine = await createEngine(canvas, this.channel, this._gameId, isHost, onGameEnd);
    } catch (error) {
      this._engineLoadError = error;
      return;
    } finally {
      if (this._engineLoadToken === loadToken) {
        this._engineLoading = false;
      }
    }

    if (this._engineLoadToken !== loadToken || this.engine) {
      engine.stop();
      return;
    }

    this.engine = engine;
    this.engine.start();

    // Hide the initialization stub text
    const stub = this.el.querySelector(".game-canvas__stub");
    if (stub) stub.classList.add("u-hidden");
  },

  _cleanup() {
    this._engineLoadToken = null;
    this._engineLoading = false;

    if (this.engine) {
      this.engine.stop();
      this.engine = null;
    }
  },

  destroyed() {
    this._cleanup();
  },
};

export default GameCanvasHook;
