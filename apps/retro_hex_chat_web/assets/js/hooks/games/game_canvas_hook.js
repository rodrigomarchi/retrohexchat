/**
 * LiveView Hook: GameCanvasHook
 *
 * Wires the game canvas to the GameEngine via the WebRTC DataChannel.
 * Listens for the game_channel_ready event from GameWebRTCHook.
 */
import { GameEngine } from "../../lib/game_engine.js";
import { PongEngine } from "../../lib/games/pong/engine.js";
import { BreakoutEngine } from "../../lib/games/breakout/engine.js";
import { SurroundEngine } from "../../lib/games/surround/engine.js";
import { StarDuelEngine } from "../../lib/games/star_duel/engine.js";
import { WarlordEngine } from "../../lib/games/warlords/engine.js";
import { PixelTanksEngine } from "../../lib/games/pixel_tanks/engine.js";
import { HexRaidEngine } from "../../lib/games/hex_raid/engine.js";
import { BoxingEngine } from "../../lib/games/hex_boxing/engine.js";
import { OutlawEngine } from "../../lib/games/hex_outlaw/engine.js";
import { HexInvadersEngine } from "../../lib/games/hex_invaders/engine.js";

/**
 * Create the appropriate engine for the given game ID.
 * @param {HTMLCanvasElement} canvas
 * @param {RTCDataChannel} channel
 * @param {string} gameId
 * @param {boolean} isHost
 * @param {function|null} onGameEnd
 * @returns {GameEngine}
 */
function createEngine(canvas, channel, gameId, isHost, onGameEnd) {
  switch (gameId) {
    case "hex_pong":
      return new PongEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "block_breakers":
      return new BreakoutEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "light_trails":
      return new SurroundEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "star_duel":
    case "gravity_well":
    case "debris_field":
      return new StarDuelEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "hex_warlords":
      return new WarlordEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "pixel_tanks":
      return new PixelTanksEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "hex_raid":
    case "hex_raid_pacifist":
    case "hex_raid_blitz":
      return new HexRaidEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "hex_boxing":
      return new BoxingEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "hex_outlaw":
    case "hex_outlaw_ricochet":
    case "hex_outlaw_stagecoach":
    case "hex_outlaw_nml":
      return new OutlawEngine(canvas, channel, gameId, isHost, onGameEnd);
    case "hex_invaders":
    case "hex_invaders_coop":
    case "hex_invaders_blitz":
      return new HexInvadersEngine(canvas, channel, gameId, isHost, onGameEnd);
    default:
      return new GameEngine(canvas, channel, gameId, isHost);
  }
}

const GameCanvasHook = {
  mounted() {
    this.engine = null;
    this.channel = null;

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
  },

  _maybeInitGame() {
    if (!this._gameId || !this.channel || this.engine) return;

    const canvas = this.el.querySelector("canvas");
    if (!canvas) return;

    const isHost = !!this._isHost;
    const onGameEnd = (result) => {
      this.pushEvent("game_result", result);
    };
    this.engine = createEngine(canvas, this.channel, this._gameId, isHost, onGameEnd);
    this.engine.start();

    // Hide the initialization stub text
    const stub = this.el.querySelector(".game-canvas__stub");
    if (stub) stub.style.display = "none";
  },

  _cleanup() {
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
