/**
 * PixelTanksEngine — extends GameEngine with top-down tank combat game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/pixel_tanks_engine
 */
import { log } from "../../logger.js";

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
  encodeGameState,
  decodeGameState,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "./protocol.js";
import { createPixelTanksAI, normalizePixelTanksAIDifficulty } from "./ai.js";
import {
  createInitialState,
  decodeMaze,
  selectMazeForMode,
  rotateTank,
  moveTank,
  fireMissile,
  updateMissile,
  updateMissileRicochet,
  checkMissileHit,
  respawnTanks,
  tickTimers,
  checkRoundEnd,
  advanceRound,
  resetForNewRound,
  createExplosion,
  // createSparks reserved for ricochet mode
  updateParticles,
  getMatchWinner,
  ROUND_DURATION,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { PixelTanksAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 1; // broadcast every fixed step (60Hz)
const ROUND_OVER_DELAY = 2500; // ms display round over screen
const SPAWNING_DELAY = 1000; // ms "ENGAGE!" display

const PIXEL_TANKS_PREVENT_DEFAULT_KEYS = new Set([
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  " ",
  "Spacebar",
  "Shift",
  "w",
  "W",
  "a",
  "A",
  "s",
  "S",
  "d",
  "D",
]);

export class PixelTanksEngine extends GameEngine {
  static INPUT_BITS = { rotateLeft: 0, rotateRight: 1, forward: 2, fire: 3 };

  static INTERPOLATION = {
    keys: ["tank1X", "tank1Y", "tank2X", "tank2Y", "m1X", "m1Y", "m2X", "m2Y"],
  };

  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {function} onGameEnd - callback when game finishes
   * @param {object} [options]
   * @param {"p2p_host"|"p2p_guest"|"solo"} [options.mode]
   * @param {object} [options.opponentController]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   */
  constructor(canvas, channel, gameId, isHost, onGameEnd, options = {}) {
    super(canvas, channel, gameId, isHost, options);
    this.onGameEnd = onGameEnd || null;

    // Determine mode from gameId — all use MAZE_BATTLE for now
    this.gameMode = GAME_MODE.MAZE_BATTLE;
    this.mazeIndex = isHost ? selectMazeForMode(this.gameMode) : 0;
    this.walls = decodeMaze(this.mazeIndex);
    this.gameState = createInitialState(this.gameMode, this.mazeIndex);
    this.particles = [];

    this.remoteInputs = {
      rotateLeft: false,
      rotateRight: false,
      forward: false,
      fire: false,
    };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new PixelTanksAudio();
    this.colors = null;
    this.peerReady = false;
    this.difficulty = normalizePixelTanksAIDifficulty(options.difficulty);
    this.opponentController =
      options.opponentController ||
      (this.mode === "solo" ? createPixelTanksAI({ difficulty: this.difficulty }) : null);
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);

    // Edge-trigger fire (only fire on press, not hold)
    this._localFirePressed = false;
    this._remoteFirePressed = false;
  }

  start() {
    if (this.running) return;
    super.start();
    this.localInputs = {
      rotateLeft: false,
      rotateRight: false,
      forward: false,
      fire: false,
    };
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.mode === "solo") {
      this.peerReady = true;
      this._invalidate();
    } else if (this.isHost) {
      this._invalidate();
    } else {
      this._advertiseReady(encodeGameReady);
      this._invalidate();
    }
  }

  stop() {
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    super.stop();
  }

  _handleMessage(event) {
    if (!(event.data instanceof ArrayBuffer)) return;
    const buf = event.data;
    const type = getMessageType(buf);
    if (type === null) return;

    switch (type) {
      case MSG_TYPE.GAME_STATE:
        if (!this.isHost) {
          const decoded = decodeGameState(buf);
          if (decoded) {
            this._ingestSnapshot(decoded, () => this._applyPeerState(decoded));
            this.setKeyboardCaptured(
              decoded.phase !== PHASE.WAITING && decoded.phase !== PHASE.MATCH_OVER,
            );
            this._invalidate();
          }
        }
        break;

      case MSG_TYPE.GAME_READY:
        if (this.isHost && !this.peerReady) {
          this.beginMatch();
        }
        break;

      case MSG_TYPE.GAME_END: {
        const result = decodeGameEnd(buf);
        if (result) {
          this.setKeyboardCaptured(false);
          this.gameState.phase = PHASE.MATCH_OVER;
          this.gameState.roundWins1 = result.roundWins1;
          this.gameState.roundWins2 = result.roundWins2;
          // Peer is P2 — determine if they won
          if (result.winner === 2) {
            this.audio.playWin();
          } else {
            this.audio.playLose();
          }
          this._invalidate();
        }
        break;
      }
    }
  }

  _applyRemoteInput(input) {
    if (input.keyCode === INPUT_KEY.ROTATE_LEFT) {
      this.remoteInputs.rotateLeft = input.pressed;
    } else if (input.keyCode === INPUT_KEY.ROTATE_RIGHT) {
      this.remoteInputs.rotateRight = input.pressed;
    } else if (input.keyCode === INPUT_KEY.FORWARD) {
      this.remoteInputs.forward = input.pressed;
    } else if (input.keyCode === INPUT_KEY.FIRE) {
      this.remoteInputs.fire = input.pressed;
    }
  }

  _applyPeerState(decoded) {
    // Update maze if needed (first state received tells peer the maze)
    if (decoded.mazeIndex !== this.mazeIndex) {
      this.mazeIndex = decoded.mazeIndex;
      this.walls = decodeMaze(decoded.mazeIndex);
    }
    if (decoded.mode !== this.gameMode) {
      this.gameMode = decoded.mode;
    }

    const prevPhase = this.gameState.phase;

    // Apply all decoded fields
    this.gameState.tank1X = decoded.tank1X;
    this.gameState.tank1Y = decoded.tank1Y;
    this.gameState.tank1Rot = decoded.tank1Rot;
    this.gameState.tank1Alive = decoded.tank1Alive;
    this.gameState.tank1Invuln = decoded.tank1Invuln;
    this.gameState.tank2X = decoded.tank2X;
    this.gameState.tank2Y = decoded.tank2Y;
    this.gameState.tank2Rot = decoded.tank2Rot;
    this.gameState.tank2Alive = decoded.tank2Alive;
    this.gameState.tank2Invuln = decoded.tank2Invuln;
    this.gameState.m1X = decoded.m1X;
    this.gameState.m1Y = decoded.m1Y;
    this.gameState.m1VX = decoded.m1VX;
    this.gameState.m1VY = decoded.m1VY;
    this.gameState.m1Active = decoded.m1Active;
    this.gameState.m1Bounced = decoded.m1Bounced;
    this.gameState.m2X = decoded.m2X;
    this.gameState.m2Y = decoded.m2Y;
    this.gameState.m2VX = decoded.m2VX;
    this.gameState.m2VY = decoded.m2VY;
    this.gameState.m2Active = decoded.m2Active;
    this.gameState.m2Bounced = decoded.m2Bounced;
    this.gameState.score1 = decoded.score1;
    this.gameState.score2 = decoded.score2;
    this.gameState.phase = decoded.phase;
    this.gameState.countdown = decoded.countdown;
    this.gameState.mode = decoded.mode;
    this.gameState.mazeIndex = decoded.mazeIndex;
    this.gameState.round = decoded.round;
    this.gameState.roundWins1 = decoded.roundWins1;
    this.gameState.roundWins2 = decoded.roundWins2;
    this.gameState.roundTimer = decoded.roundTimer;

    this._playPhaseAudio(prevPhase, decoded.phase);
  }

  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    this._setLocalInput(keyCode, true);
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    this._setLocalInput(keyCode, false);
  }

  _setLocalInput(keyCode, pressed) {
    if (keyCode === INPUT_KEY.ROTATE_LEFT) this.localInputs.rotateLeft = pressed;
    else if (keyCode === INPUT_KEY.ROTATE_RIGHT) this.localInputs.rotateRight = pressed;
    else if (keyCode === INPUT_KEY.FORWARD) this.localInputs.forward = pressed;
    else if (keyCode === INPUT_KEY.FIRE) this.localInputs.fire = pressed;
  }

  _mapKey(key) {
    if (key === "ArrowLeft" || key === "a" || key === "A") return INPUT_KEY.ROTATE_LEFT;
    if (key === "ArrowRight" || key === "d" || key === "D") return INPUT_KEY.ROTATE_RIGHT;
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.FORWARD;
    if (key === " " || key === "Shift") return INPUT_KEY.FIRE;
    return null;
  }

  _handleBlur() {
    this.localInputs = {
      rotateLeft: false,
      rotateRight: false,
      forward: false,
      fire: false,
    };
    this._sendInputState();
  }

  // --- Phase management (host only) ---

  beginMatch(options = {}) {
    if (
      !this.running ||
      !this.isHost ||
      !this.gameState ||
      this.gameState.phase !== PHASE.WAITING
    ) {
      return false;
    }

    if (options.difficulty) {
      this.difficulty = normalizePixelTanksAIDifficulty(options.difficulty);
      if (
        !options.opponentController &&
        typeof this.opponentController?.setDifficulty === "function"
      ) {
        this.opponentController.setDifficulty(this.difficulty);
      }
    }
    if (options.opponentController) this.opponentController = options.opponentController;
    if (this.mode === "solo" && !this.opponentController) {
      this.opponentController = createPixelTanksAI({ difficulty: this.difficulty });
    }

    this.setKeyboardCaptured(true);
    this.peerReady = true;
    this._startCountdown();
    return true;
  }

  _startCountdown() {
    this.setKeyboardCaptured(true);
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._invalidate();
    this.audio.playCountdown();

    let count = 3;
    const tick = () => {
      if (!this.running) return;
      count--;
      if (count > 0) {
        this.gameState.countdown = count;
        this._broadcastState();
        this._invalidate();
        this.audio.playCountdown();
        this.phaseTimer = setTimeout(tick, 1000);
      } else {
        this._startSpawning();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  _startSpawning() {
    this.setKeyboardCaptured(true);
    this.gameState.phase = PHASE.SPAWNING;
    this._broadcastState();
    this._invalidate();
    this.audio.playSpawn();

    this.phaseTimer = setTimeout(() => {
      if (!this.running || !this.gameState) return;
      this.gameState.phase = PHASE.PLAYING;
      this.gameState.roundTimer = ROUND_DURATION;
      this._broadcastState();
      this._startGameLoop();
    }, SPAWNING_DELAY);
  }

  _startGameLoop() {
    this.setKeyboardCaptured(true);
    this.frameCount = 0;
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    this._startSteps();
  }

  /** Let the round's particles settle while the simulation is paused. */
  _idleStep() {
    if (!this.particles.length) return;
    this.particles = updateParticles(this.particles);
    this._invalidate();
  }

  _gameLoop() {
    if (!this.running || !this.isHost || !this.gameState) return;

    this._updateOpponentInputs();
    let s = this.gameState;

    // Skip physics during respawn pause
    if (s.respawnPause > 0) {
      s = tickTimers(s);
      this.gameState = s;
      this.particles = updateParticles(this.particles);
      this._invalidate();
      this.frameCount++;
      if (this.frameCount % STATE_SEND_INTERVAL === 0) {
        this._broadcastState();
      }
      return;
    }

    // Clear event flags
    s = { ...s, tankHit: 0, missileExpired: 0, wallBounced: 0 };

    // P1 inputs (host = P1)
    if (this.localInputs.rotateLeft) s = rotateTank(s, 1, -1);
    if (this.localInputs.rotateRight) s = rotateTank(s, 1, 1);
    if (this.localInputs.forward) s = moveTank(s, 1, this.walls);

    // P2 inputs (remote = P2)
    if (this.remoteInputs.rotateLeft) s = rotateTank(s, 2, -1);
    if (this.remoteInputs.rotateRight) s = rotateTank(s, 2, 1);
    if (this.remoteInputs.forward) s = moveTank(s, 2, this.walls);

    // Fire missiles (edge-triggered: fire on press, not hold)
    if (this.localInputs.fire && !this._localFirePressed) {
      s = fireMissile(s, 1, this.walls);
      if (s.m1Active && this.gameState.m1Active !== s.m1Active) {
        this.audio.playFire();
      }
    }
    this._localFirePressed = this.localInputs.fire;

    if (this.remoteInputs.fire && !this._remoteFirePressed) {
      s = fireMissile(s, 2, this.walls);
      if (s.m2Active && this.gameState.m2Active !== s.m2Active) {
        this.audio.playFire();
      }
    }
    this._remoteFirePressed = this.remoteInputs.fire;

    // Update missiles
    if (this.gameMode === GAME_MODE.RICOCHET) {
      s = updateMissileRicochet(s, 1, this.walls);
      s = updateMissileRicochet(s, 2, this.walls);
    } else {
      s = updateMissile(s, 1, this.walls);
      s = updateMissile(s, 2, this.walls);
    }

    // Audio for missile events
    if (s.wallBounced) {
      this.audio.playRicochet();
    }

    // Check missile-tank collisions
    s = checkMissileHit(s, 1); // missile 1 hits tank 2
    s = checkMissileHit(s, 2); // missile 2 hits tank 1

    // Handle tank hit
    if (s.tankHit !== 0) {
      this.audio.playHit();
      const hitX = s.tankHit === 1 ? s.tank1X : s.tank2X;
      const hitY = s.tankHit === 1 ? s.tank1Y : s.tank2Y;
      this.particles = [...this.particles, ...createExplosion(hitX, hitY)];
      s = respawnTanks(s);
    }

    // Tick timers
    s = tickTimers(s);

    // Timer tick audio (last 15 seconds = 900 frames)
    if (s.roundTimer <= 900 && s.roundTimer > 0 && s.roundTimer % 60 === 0) {
      this.audio.playTimerTick();
    }

    // Check round end
    const { ended, roundWinner } = checkRoundEnd(s);
    if (ended) {
      s = advanceRound(s, roundWinner);
      this.audio.playRoundEnd();

      if (s.phase === PHASE.MATCH_OVER) {
        this.gameState = s;
        this._handleMatchOver();
        return;
      }

      // Round over — keep rendering particles during pause, then start next round
      this.gameState = s;
      this._broadcastState();
      this._stopSteps();

      this.phaseTimer = setTimeout(() => {
        if (!this.running) return;
        this.gameState = resetForNewRound(this.gameState);
        this._startCountdown();
      }, ROUND_OVER_DELAY);
      return;
    }

    // Update particles
    this.particles = updateParticles(this.particles);

    // Save state and render
    this.gameState = s;
    this._invalidate();

    // Broadcast
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }
  }

  _handleMatchOver() {
    this.setKeyboardCaptured(false);
    this._stopSteps();
    const winner = getMatchWinner(this.gameState);

    if (winner === 1) {
      this.audio.playWin();
    } else {
      this.audio.playLose();
    }

    // Send GAME_END to peer
    this._sendCommand(
      encodeGameEnd({
        score1: this.gameState.score1,
        score2: this.gameState.score2,
        winner,
        roundWins1: this.gameState.roundWins1,
        roundWins2: this.gameState.roundWins2,
      }),
    );
    this._broadcastState();
    this._invalidate();

    if (this.onGameEnd) {
      this.onGameEnd({
        score: {
          p1: this.gameState.roundWins1,
          p2: this.gameState.roundWins2,
        },
        winner,
      });
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    this.setKeyboardCaptured(false);
    this._stopSteps();
    if (!this.gameState || this.gameState.phase === PHASE.MATCH_OVER) return;
    this.gameState.phase = PHASE.MATCH_OVER;
    this._invalidate();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: {
            p1: this.gameState.roundWins1,
            p2: this.gameState.roundWins2,
          },
          winner: 0,
          disconnected: true,
        });
      } catch (error) {
        // The disconnect result callback (pushEvent) threw — do not lose it.
        log.debug("[GameEngine] game-end callback failed", error);
      }
    }
  }

  _broadcastState() {
    this._sendState(encodeGameState(this.gameState));
  }

  _renderState() {
    if (this.colors) {
      renderFrame(
        this.ctx,
        this.gameState,
        this.colors,
        this.walls,
        performance.now(),
        this.particles,
      );
    }
  }

  _playPhaseAudio(prevPhase, newPhase) {
    if (prevPhase === newPhase) return;
    if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
    if (newPhase === PHASE.SPAWNING) this.audio.playSpawn();
    if (newPhase === PHASE.ROUND_OVER) this.audio.playRoundEnd();
  }

  _updateOpponentInputs() {
    if (this.mode !== "solo" || typeof this.opponentController?.nextInputs !== "function") return;

    const nextInputs = this.opponentController.nextInputs({
      state: this.gameState,
      gameMode: this.gameMode,
      walls: this.walls,
      difficulty: this.difficulty,
      player: 2,
    });

    if (!nextInputs) return;

    this.remoteInputs = {
      rotateLeft: nextInputs.rotateLeft === true,
      rotateRight: nextInputs.rotateRight === true,
      forward: nextInputs.forward === true,
      fire: nextInputs.fire === true,
    };
  }

  _shouldPreventDefaultForCapturedKey(event) {
    return PIXEL_TANKS_PREVENT_DEFAULT_KEYS.has(event.key);
  }
}
