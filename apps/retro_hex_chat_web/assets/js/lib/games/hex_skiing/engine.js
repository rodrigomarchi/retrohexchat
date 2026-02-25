/**
 * Hex Skiing — Main game engine.
 *
 * Extends GameEngine with the skiing-specific game loop, input handling,
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
  updateSkier,
  updateScroll,
  ensureChunks,
  ensureGates,
  updateItems,
  checkCollisions,
  checkGates,
  updateAvalanche,
  updateBlizzard,
  checkGameOver,
  startNextRound,
  determineWinner,
  getScrollSpeed,
} from "./physics.js";
import { render, readColors, generateSnowParticles } from "./renderer.js";
import { HexSkiingAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Broadcast every 2 frames (~30Hz)
const COUNTDOWN_INTERVAL = 60; // Frames per countdown tick
const ROUND_END_DELAY = 180; // Frames to show round-end screen

/**
 * Map gameId string to GAME_MODE enum.
 */
function resolveMode(gameId) {
  switch (gameId) {
    case "hex_skiing_escape":
      return GAME_MODE.AVALANCHE_ESCAPE;
    case "hex_skiing_clean":
      return GAME_MODE.CLEAN_RUN;
    default:
      return GAME_MODE.ALPINE_RACE;
  }
}

export class HexSkiingEngine extends GameEngine {
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
    this.localInputs = { left: false, right: false };
    this.remoteInputs = { left: false, right: false };
    this.frameCount = 0;
    this.peerReady = false;
    this.phaseTimer = 0;
    this.roundEndTimer = 0;

    this.audio = new HexSkiingAudio();
    this.colors = null;
    this.snowParticles = null;
  }

  start() {
    super.start();

    this.colors = readColors(this.canvas);
    this.snowParticles = generateSnowParticles(40);

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
    super.stop();
    this.audio.destroy();
    this.localInputs = { left: false, right: false };
    this.remoteInputs = { left: false, right: false };
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
      if (this.peerReady) return; // Guard against duplicate GAME_READY
      this.peerReady = true;
      this._startCountdown();
    } else if (type === MSG_TYPE.GAME_STATE && !this.isHost) {
      const decoded = decodeGameState(buf);
      if (decoded) {
        const prev = this.gameState;
        this.gameState = unpackState(decoded);
        // Preserve obstacles/gates/items on peer (they're deterministic or included)
        this._handlePeerEvents(decoded.events, prev);
        this._renderState();
      }
    } else if (type === MSG_TYPE.PLAYER_INPUT && this.isHost) {
      const input = decodePlayerInput(buf);
      if (input) {
        if (input.keyCode === INPUT_KEY.LEFT) {
          this.remoteInputs.left = input.pressed;
        }
        if (input.keyCode === INPUT_KEY.RIGHT) {
          this.remoteInputs.right = input.pressed;
        }
      }
    } else if (type === MSG_TYPE.GAME_END && !this.isHost) {
      const result = decodeGameEnd(buf);
      if (result) {
        this.audio.stopSkiDrone();
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

    if (this.isHost) {
      if (key === INPUT_KEY.LEFT) this.localInputs.left = true;
      if (key === INPUT_KEY.RIGHT) this.localInputs.right = true;
    } else {
      if (key === INPUT_KEY.LEFT) this.localInputs.left = true;
      if (key === INPUT_KEY.RIGHT) this.localInputs.right = true;
      this._safeSend(encodePlayerInput(key, true));
    }
  }

  _handleKeyUp(event) {
    const key = this._mapKey(event);
    if (key === null) return;
    event.preventDefault();

    if (this.isHost) {
      if (key === INPUT_KEY.LEFT) this.localInputs.left = false;
      if (key === INPUT_KEY.RIGHT) this.localInputs.right = false;
    } else {
      if (key === INPUT_KEY.LEFT) this.localInputs.left = false;
      if (key === INPUT_KEY.RIGHT) this.localInputs.right = false;
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
    this._broadcastState();
    this._startGameLoop();
  }

  _startGameLoop() {
    if (this.animFrame) return; // Guard against duplicate game loops
    this.audio.startSkiDrone();
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
    state.events = 0; // Clear event flags each frame

    if (state.phase === PHASE.COUNTDOWN) {
      this.phaseTimer--;
      if (this.phaseTimer <= 0) {
        state.countdown--;
        if (state.countdown <= 0) {
          state.phase = PHASE.RACING;
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

    if (state.phase === PHASE.ROUND_END) {
      this.roundEndTimer--;
      if (this.roundEndTimer <= 0) {
        state = startNextRound(state);
        this.phaseTimer = COUNTDOWN_INTERVAL;
        this.audio.playCountdown();
      }
      this.gameState = state;
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    if (state.phase === PHASE.FINISHED) {
      // Game is over — send final state then stop the loop
      this._renderState();
      this._broadcastState();
      this.running = false;
      return;
    }

    if (state.phase !== PHASE.RACING) {
      this._renderState();
      return;
    }

    // ── RACING phase ──

    // Update skiers
    state.p1 = updateSkier(state.p1, this.localInputs);
    state.p2 = updateSkier(state.p2, this.remoteInputs);

    // Update scroll
    state = updateScroll(state);

    // Generate terrain
    state = ensureChunks(state);
    state = ensureGates(state);
    state = updateItems(state);

    // Collisions
    state = checkCollisions(state);
    state = checkGates(state);

    // Avalanche
    state = updateAvalanche(state);

    // Blizzard
    state = updateBlizzard(state);

    // Check game over
    const prevPhase = state.phase;
    state = checkGameOver(state);

    // Phase transitions
    if (state.phase === PHASE.ROUND_END && prevPhase === PHASE.RACING) {
      this.roundEndTimer = ROUND_END_DELAY;
      this.audio.playRoundEnd();
    }

    if (state.phase === PHASE.FINISHED && prevPhase !== PHASE.FINISHED) {
      this._handleGameFinished(state);
    }

    // Audio events
    this._handleHostEvents(state.events);

    // Update drone pitch based on faster skier's speed
    const speed = Math.max(getScrollSpeed(state.p1), getScrollSpeed(state.p2));
    this.audio.updateSkiPitch(speed);

    // Avalanche rumble
    if (state.mode !== GAME_MODE.CLEAN_RUN) {
      const avalancheScreenY = state.avalancheY - state.scrollY;
      const proximity = Math.max(0, Math.min(1, avalancheScreenY / 380));
      if (proximity > 0.3 && this.frameCount % 20 === 0) {
        this.audio.playAvalancheRumble(proximity);
      }
    }

    state.frameCount = this.frameCount;
    this.gameState = state;

    // Render
    this._renderState();

    // Broadcast
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }
  }

  // ── Audio event handling ─────────────────────────────────────

  _handleHostEvents(events) {
    if (events & EVENT.COLLISION_TREE) this.audio.playCollisionTree();
    if (events & EVENT.COLLISION_ROCK) this.audio.playCollisionRock();
    if (events & EVENT.GATE_CLEARED) this.audio.playGateCleared();
    if (events & EVENT.SPEED_BOOST) this.audio.playSpeedBoost();
    if (events & EVENT.ICE_PATCH) this.audio.playIcePatch();
    if (events & EVENT.BLIZZARD_START) this.audio.playBlizzardStart();
    if (events & EVENT.BLIZZARD_END) this.audio.playBlizzardEnd();
    if (events & EVENT.ENGULFED) this.audio.playEngulfed();
  }

  _handlePeerEvents(events, _prevState) {
    if (events & EVENT.COLLISION_TREE) this.audio.playCollisionTree();
    if (events & EVENT.COLLISION_ROCK) this.audio.playCollisionRock();
    if (events & EVENT.GATE_CLEARED) this.audio.playGateCleared();
    if (events & EVENT.SPEED_BOOST) this.audio.playSpeedBoost();
    if (events & EVENT.ICE_PATCH) this.audio.playIcePatch();
    if (events & EVENT.BLIZZARD_START) this.audio.playBlizzardStart();
    if (events & EVENT.BLIZZARD_END) this.audio.playBlizzardEnd();
    if (events & EVENT.ENGULFED) this.audio.playEngulfed();
  }

  // ── Game end ─────────────────────────────────────────────────

  _handleGameFinished(state) {
    const winner = determineWinner(state);
    this.audio.stopSkiDrone();

    if (winner > 0) {
      this.audio.playVictory();
    } else {
      this.audio.playGameOver();
    }

    // Send GAME_END to peer
    const result = {
      score1: state.p1RoundWins,
      score2: state.p2RoundWins,
      winner,
    };
    this._safeSend(encodeGameEnd(result));

    // Report to LiveView
    if (this.onGameEnd) {
      this.onGameEnd(result);
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
