/**
 * LiveView Hook: LobbyGameCanvasHook
 *
 * Wires the lobby game canvas to a GameEngine over the shared "gamedata"
 * DataChannel exposed by LobbyWebRTCHook. Identical in spirit to
 * games/game_canvas_hook.js, but bound to the lobby's persistent connection
 * (element id "lobby-webrtc") so a game can run alongside an active call and
 * file transfer.
 */
import { log } from "../../lib/logger.js";
import { createGameEngine } from "../../lib/games/engine_loader.js";

const LobbyGameCanvasHook = {
  mounted() {
    this.engine = null;
    this.channel = null;
    this._engineLoadToken = null;
    this._engineLoading = false;
    this._gameId = this.el.dataset.gameId || null;
    this._isHost = this.el.dataset.isHost === "true";

    const webrtcEl = document.getElementById("lobby-webrtc");
    if (webrtcEl) {
      webrtcEl.addEventListener("game_channel_ready", (e) => {
        this.channel = e.detail.channel;
        this._maybeInitGame();
      });

      if (webrtcEl._gameDataChannel) {
        this.channel = webrtcEl._gameDataChannel;
        this._maybeInitGame();
      }
    }

    this.handleEvent("lobby_game_start", ({ game_id, is_host }) => {
      this._gameId = game_id;
      this._isHost = is_host;
      this._maybeInitGame();
    });

    this.handleEvent("lobby_game_end", () => {
      this._cleanup();
    });

    this.pushEvent("lobby_game_canvas_ready", {});
  },

  async _maybeInitGame() {
    if (!this._gameId || !this.channel || this.engine || this._engineLoading) return;

    const canvas = this.el.querySelector("canvas");
    if (!canvas) return;

    const isHost = !!this._isHost;
    const onGameEnd = (result) => {
      this.pushEvent("lobby_game_result", result);
    };
    const loadToken = {};
    this._engineLoadToken = loadToken;
    this._engineLoading = true;

    let engine;

    try {
      engine = await createGameEngine({
        canvas,
        channel: this.channel,
        gameId: this._gameId,
        mode: isHost ? "p2p_host" : "p2p_guest",
        isHost,
        onGameEnd,
      });
    } catch (error) {
      log.error("[LobbyGameCanvasHook] failed to load game engine", error);
      this.pushEvent("lobby_game_error", { game_id: this._gameId });
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

    // The call reports its own health to the server every few seconds; the game
    // now does the same, so a match that stuttered leaves something behind to
    // look at instead of only a memory of it.
    engine.onTelemetry = (sample) => this.pushEvent("lobby_game_telemetry", sample);

    this.engine = engine;
    this.engine.start();

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

export default LobbyGameCanvasHook;
