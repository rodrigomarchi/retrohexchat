/**
 * LiveView Hook: GameCanvasHook
 *
 * Wires the game canvas to the GameEngine via the WebRTC DataChannel.
 * Listens for the game_channel_ready event from GameWebRTCHook.
 */
import { GameEngine } from "../lib/game_engine.js";

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

    this.handleEvent("game_start", ({ game_id, role }) => {
      this._gameId = game_id;
      this._role = role;
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

    const isHost = this._role === "creator";
    this.engine = new GameEngine(canvas, this.channel, this._gameId, isHost);
    this.engine.start();
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
