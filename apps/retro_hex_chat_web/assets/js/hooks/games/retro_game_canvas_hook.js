import { log } from "../../lib/logger.js";
import { createGameEngine } from "../../lib/games/engine_loader.js";

export function createRetroGameCanvasHook({ engineFactory = createGameEngine } = {}) {
  return {
    mounted() {
      this.engine = null;
      this.canvas = this.el.querySelector("canvas");
      this._engineFactory = engineFactory;
      this._engineLoading = false;
      this._engineLoadToken = null;
      this._gameId = this.el.dataset.gameId || null;
      this._difficulty = this.el.dataset.difficulty || "normal";
      this._boundFocusGameSurface = this._focusGameSurface.bind(this);
      this.el.addEventListener("pointerdown", this._boundFocusGameSurface);

      this.handleEvent("retro_game_begin", (payload = {}) => {
        this._beginMatch(payload);
      });

      this.handleEvent("retro_game_stop", (payload = {}) => {
        this._stopMatch(payload);
      });

      this._enginePromise = this._maybeInitGame();
    },

    updated() {
      const nextDifficulty = this.el.dataset.difficulty;
      if (nextDifficulty) this._difficulty = nextDifficulty;
    },

    async _maybeInitGame() {
      if (!this._gameId || !this.canvas || this.engine || this._engineLoading) return null;

      const loadToken = {};
      this._engineLoadToken = loadToken;
      this._engineLoading = true;

      let engine;

      try {
        engine = await this._engineFactory({
          canvas: this.canvas,
          gameId: this._gameId,
          mode: "solo",
          isHost: true,
          difficulty: this._difficulty,
          onGameEnd: (result) => this._reportResult(result),
        });
      } catch (error) {
        if (this._engineLoadToken === loadToken) {
          log.error("[RetroGameCanvasHook] failed to load game engine", error);
          this.pushEvent("retro_game_error", {
            game_id: this._gameId,
            reason: "engine_load_failed",
          });
        }

        return null;
      } finally {
        if (this._engineLoadToken === loadToken) {
          this._engineLoading = false;
        }
      }

      if (this._engineLoadToken !== loadToken || this.engine) {
        engine.stop?.();
        return null;
      }

      this.engine = engine;
      this.engine.start();
      this._hideStub();
      this.pushEvent("retro_game_canvas_ready", { game_id: this._gameId });
      return engine;
    },

    _beginMatch(payload = {}) {
      if (payload.game_id && payload.game_id !== this._gameId) return;
      if (!this.engine || typeof this.engine.beginMatch !== "function") return;

      this._difficulty = payload.difficulty || this._difficulty;
      const started = this.engine.beginMatch({ difficulty: this._difficulty });

      if (!started) {
        this.pushEvent("retro_game_error", {
          game_id: this._gameId,
          reason: "begin_failed",
        });
        return;
      }

      this._focusGameSurface();
    },

    _stopMatch(payload = {}) {
      if (payload.game_id && payload.game_id !== this._gameId) return;
      this._cleanup();
    },

    _reportResult(result = {}) {
      this.pushEvent("retro_game_result", {
        ...result,
        game_id: this._gameId,
      });
    },

    _cleanup() {
      this._engineLoadToken = null;
      this._engineLoading = false;

      if (this.engine) {
        this.engine.stop();
        this.engine = null;
      }
    },

    _hideStub() {
      const stub = this.el.querySelector(".game-canvas__stub");
      if (stub) stub.classList.add("u-hidden");
    },

    _focusGameSurface() {
      this.el.focus();
    },

    destroyed() {
      this.el.removeEventListener("pointerdown", this._boundFocusGameSurface);
      this._cleanup();
    },
  };
}

export default createRetroGameCanvasHook();
