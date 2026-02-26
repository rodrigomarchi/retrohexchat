/**
 * Hex Frost — Main game engine.
 *
 * Extends GameEngine with the Frostbite-specific game loop, input handling,
 * network sync, and lifecycle management.
 *
 * Host is authoritative: runs physics at 60fps, broadcasts state ~30Hz.
 * Peer sends input only and renders received state.
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  EVENT,
  getMessageType,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
} from "./protocol.js";
import {
  createInitialState,
  packState,
  unpackState,
  updateBlocks,
  updateBailey,
  updateEnemies,
  checkEnemyCollisions,
  spawnFish,
  updateFish,
  updateTemperature,
  handleRespawns,
  checkIglooEntry,
  checkRoundEnd,
  startNextRound,
  updateFlashTimers,
  determineWinner,
} from "./physics.js";
import { render, readColors, generateSnowParticles } from "./renderer.js";
import { HexFrostAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Broadcast every 2 frames (~30Hz)
const COUNTDOWN_INTERVAL = 60; // Frames per countdown tick
const ROUND_END_DELAY = 180; // Frames to show round-end screen

/**
 * Map gameId string to GAME_MODE enum.
 */
function resolveMode(gameId) {
  switch (gameId) {
    case "hex_frost_blizzard":
      return GAME_MODE.BLIZZARD;
    case "hex_frost_peaceful":
      return GAME_MODE.PEACEFUL;
    default:
      return GAME_MODE.ARCTIC_RACE;
  }
}

export class HexFrostEngine extends GameEngine {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {function|null} onGameEnd
   */
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd || null;
    this.mode = resolveMode(gameId);

    this.gameState = null;
    this.localInputs = { left: false, right: false, up: false, down: false };
    this.remoteInputs = { left: false, right: false, up: false, down: false };
    this.frameCount = 0;
    this.peerReady = false;
    this.phaseTimer = 0;
    this.roundEndTimer = 0;

    this.audio = new HexFrostAudio();
    this.colors = null;
    this.snowParticles = null;
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    this.colors = readColors(this.canvas);
    this.snowParticles = generateSnowParticles(35);

    if (this.isHost) {
      const seed = (Math.random() * 0xffffffff) >>> 0;
      this.gameState = createInitialState(this.mode, seed);
      this._renderState();
    } else {
      this._safeSend(encodeGameReady());
      this._renderState();
    }
  }

  stop() {
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    super.stop();
    this.audio.destroy();
    this.localInputs = { left: false, right: false, up: false, down: false };
    this.remoteInputs = { left: false, right: false, up: false, down: false };
    this.peerReady = false;
    this.frameCount = 0;
    this.phaseTimer = 0;
    this.roundEndTimer = 0;
  }

  // ── Network messages ─────────────────────────────────────────

  _handleMessage(event) {
    if (!(event.data instanceof ArrayBuffer)) return;
    const buf = event.data;
    const type = getMessageType(buf);

    if (type === MSG_TYPE.GAME_READY && this.isHost) {
      if (this.peerReady) return;
      this.peerReady = true;
      this._startCountdown();
    } else if (type === MSG_TYPE.GAME_STATE && !this.isHost) {
      const decoded = decodeGameState(buf);
      if (decoded) {
        this.gameState = unpackState(decoded);
        this._handlePeerEvents(decoded.events);
        this._renderState();
      }
    } else if (type === MSG_TYPE.PLAYER_INPUT && this.isHost) {
      const input = decodePlayerInput(buf);
      if (input) {
        if (input.keyCode === INPUT_KEY.LEFT) this.remoteInputs.left = input.pressed;
        if (input.keyCode === INPUT_KEY.RIGHT) this.remoteInputs.right = input.pressed;
        if (input.keyCode === INPUT_KEY.UP) this.remoteInputs.up = input.pressed;
        if (input.keyCode === INPUT_KEY.DOWN) this.remoteInputs.down = input.pressed;
      }
    } else if (type === MSG_TYPE.GAME_END && !this.isHost) {
      const result = decodeGameEnd(buf);
      if (result) {
        this.audio.stopAmbientWind();
        if (result.winner > 0) {
          this.audio.playVictory();
        } else {
          this.audio.playGameOver();
        }
        if (this.onGameEnd) {
          this.onGameEnd(result);
        }
      }
    }
  }

  // ── Input handling ───────────────────────────────────────────

  _handleKeyDown(event) {
    const key = this._mapKey(event);
    if (key === null) return;
    event.preventDefault();

    if (key === INPUT_KEY.LEFT) this.localInputs.left = true;
    if (key === INPUT_KEY.RIGHT) this.localInputs.right = true;
    if (key === INPUT_KEY.UP) this.localInputs.up = true;
    if (key === INPUT_KEY.DOWN) this.localInputs.down = true;

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(key, true));
    }
  }

  _handleKeyUp(event) {
    const key = this._mapKey(event);
    if (key === null) return;
    event.preventDefault();

    if (key === INPUT_KEY.LEFT) this.localInputs.left = false;
    if (key === INPUT_KEY.RIGHT) this.localInputs.right = false;
    if (key === INPUT_KEY.UP) this.localInputs.up = false;
    if (key === INPUT_KEY.DOWN) this.localInputs.down = false;

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(key, false));
    }
  }

  _mapKey(event) {
    switch (event.key) {
      case "ArrowLeft":
      case "a":
      case "A":
        return INPUT_KEY.LEFT;
      case "ArrowRight":
      case "d":
      case "D":
        return INPUT_KEY.RIGHT;
      case "ArrowUp":
      case "w":
      case "W":
        return INPUT_KEY.UP;
      case "ArrowDown":
      case "s":
      case "S":
        return INPUT_KEY.DOWN;
      default:
        return null;
    }
  }

  // ── Game lifecycle ───────────────────────────────────────────

  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this.phaseTimer = COUNTDOWN_INTERVAL;
    this.audio.playCountdown();
    this.audio.startAmbientWind();
    this._broadcastState();
    this._startGameLoop();
  }

  _startGameLoop() {
    if (this.animFrame) return;
    const loop = () => {
      if (!this.running) return;
      this._gameLoop();
      this.animFrame = requestAnimationFrame(loop);
    };
    this.animFrame = requestAnimationFrame(loop);
  }

  // ── Main game loop (host only) ───────────────────────────────

  _gameLoop() {
    if (!this.isHost || !this.gameState) return;

    this.frameCount++;
    let state = { ...this.gameState };
    state.events = 0;
    state.frameCount = this.frameCount;

    // ── COUNTDOWN phase ──
    if (state.phase === PHASE.COUNTDOWN) {
      this.phaseTimer--;
      if (this.phaseTimer <= 0) {
        state.countdown--;
        if (state.countdown <= 0) {
          state.phase = PHASE.BUILDING;
          state.countdown = 0;
          this.audio.playCountdownGo();
        } else {
          this.phaseTimer = COUNTDOWN_INTERVAL;
          this.audio.playCountdown();
        }
      }
      this.gameState = state;
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── ROUND_END phase ──
    if (state.phase === PHASE.ROUND_END) {
      this.roundEndTimer--;
      if (this.roundEndTimer <= 0) {
        state = startNextRound(state);
        if (state.phase === PHASE.COUNTDOWN) {
          this.phaseTimer = COUNTDOWN_INTERVAL;
          this.audio.playCountdown();
        }
      }
      this.gameState = state;
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── FINISHED phase ──
    if (state.phase === PHASE.FINISHED) {
      this._renderState();
      this._broadcastState();
      this.running = false;
      return;
    }

    if (state.phase !== PHASE.BUILDING) {
      this._renderState();
      return;
    }

    // ── BUILDING phase (main gameplay) ──

    // Update block positions
    state = updateBlocks(state);

    // Update players
    state = updateBailey(state, "p1", this.localInputs);
    // Reset up/down after processing (jump is one-shot)
    this.localInputs.up = false;
    this.localInputs.down = false;

    state = updateBailey(state, "p2", this.remoteInputs);
    this.remoteInputs.up = false;
    this.remoteInputs.down = false;

    // Update enemies
    state = updateEnemies(state);

    // Spawn & update fish
    state = spawnFish(state);
    state = updateFish(state);

    // Check enemy collisions
    state = checkEnemyCollisions(state, "p1");
    state = checkEnemyCollisions(state, "p2");

    // Handle respawns
    state = handleRespawns(state);

    // Update temperature
    state = updateTemperature(state);

    // Check igloo entry
    state = checkIglooEntry(state);

    // Check round end
    const prevPhase = state.phase;
    state = checkRoundEnd(state);

    // Phase transitions
    if (state.phase === PHASE.ROUND_END && prevPhase === PHASE.BUILDING) {
      this.roundEndTimer = ROUND_END_DELAY;
      this.audio.playRoundEnd();
    }

    if (state.phase === PHASE.FINISHED && prevPhase !== PHASE.FINISHED) {
      this._handleGameFinished(state);
    }

    // Update visual flash timers
    state = updateFlashTimers(state);

    // Audio events
    this._handleHostEvents(state.events);

    this.gameState = state;
    this._renderState();

    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }
  }

  // ── Audio event handling ─────────────────────────────────────

  _handleHostEvents(events) {
    if (events & EVENT.BLOCK_CLAIM) this.audio.playBlockClaim();
    if (events & EVENT.BLOCK_STEAL) this.audio.playBlockSteal();
    if (events & EVENT.BLOCK_UNDO) this.audio.playBlockUndo();
    if (events & EVENT.JUMP) this.audio.playJump();
    if (events & EVENT.LAND) this.audio.playLand();
    if (events & EVENT.SPLASH) this.audio.playSplash();
    if (events & EVENT.FISH_COLLECT) this.audio.playFishCollect();
    if (events & EVENT.ENEMY_HIT) this.audio.playEnemyHit();
    if (events & EVENT.IGLOO_PIECE) this.audio.playIglooPiece();
    if (events & EVENT.IGLOO_LOSE) this.audio.playIglooLose();
    if (events & EVENT.IGLOO_COMPLETE) this.audio.playIglooComplete();
    if (events & EVENT.IGLOO_ENTER) this.audio.playIglooEnter();
    if (events & EVENT.TEMP_LOW) this.audio.playTempLow();
    if (events & EVENT.TEMP_ZERO) this.audio.playTempZero();
    if (events & EVENT.BEAR_NEAR) this.audio.playBearNear();
    if (events & EVENT.CLAM_SNAP) this.audio.playClamSnap();
  }

  _handlePeerEvents(events) {
    this._handleHostEvents(events);
  }

  // ── Game end ─────────────────────────────────────────────────

  _handleGameFinished(state) {
    const winner = determineWinner(state);
    this.audio.stopAmbientWind();

    if (winner > 0) {
      this.audio.playVictory();
    } else {
      this.audio.playGameOver();
    }

    const result = {
      score1: state.p1.roundWins,
      score2: state.p2.roundWins,
      winner,
    };
    this._safeSend(encodeGameEnd(result));

    if (this.onGameEnd) {
      this.onGameEnd(result);
    }
  }

  // ── Connection Resilience ──

  _handleBlur() {
    this.localInputs = { left: false, right: false, up: false, down: false };
  }

  _handleChannelClose() {
    if (!this.gameState || this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this._renderState();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          winner: "draw",
          score_p1: this.gameState.p1?.roundWins ?? this.gameState.p1RoundWins ?? 0,
          score_p2: this.gameState.p2?.roundWins ?? this.gameState.p2RoundWins ?? 0,
          disconnected: true,
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  // ── Render / broadcast helpers ───────────────────────────────

  _renderState() {
    render(this.ctx, this.gameState, this.colors, this.frameCount, this.snowParticles);
  }

  _broadcastState() {
    if (!this.gameState) return;
    const packed = packState(this.gameState);
    this._safeSend(encodeGameState(packed));
  }
}
