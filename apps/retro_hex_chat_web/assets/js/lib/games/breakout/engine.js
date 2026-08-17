/**
 * BreakoutEngine — extends GameEngine with Block Breakers co-op game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/breakout_engine
 */
import { log } from "../../logger.js";

import { GameEngine } from "../../game_engine.js";
import { createBreakoutAI, normalizeBreakoutAIDifficulty } from "./ai.js";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  encodeGameState,
  decodeGameState,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "./protocol.js";
import {
  BALL_SIZE,
  createInitialState,
  updatePaddle,
  updateBall,
  checkWallBounce,
  checkPaddleCollision,
  checkBlockCollision,
  checkLifeLost,
  checkWin,
  serveBall,
  createBlockParticles,
  updateParticles,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { BreakoutAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 1; // broadcast every fixed step (60Hz)
const SERVE_DELAY = 800; // ms
const LIFE_LOST_PAUSE = 1500; // ms
const BREAKOUT_PREVENT_DEFAULT_KEYS = new Set([
  "ArrowLeft",
  "ArrowRight",
  "ArrowUp",
  "ArrowDown",
  " ",
  "Spacebar",
  "a",
  "A",
  "d",
  "D",
]);

export class BreakoutEngine extends GameEngine {
  static INPUT_BITS = { left: 0, right: 1 };

  static INTERPOLATION = {
    keys: ["ballX", "ballY", "paddle1X", "paddle2X"],
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
    this.gameState = createInitialState();
    this.localInputs = { left: false, right: false };
    this.remoteInputs = { left: false, right: false };
    this.difficulty = normalizeBreakoutAIDifficulty(options.difficulty);
    this.opponentController =
      options.opponentController ||
      (this.mode === "solo" ? createBreakoutAI({ difficulty: this.difficulty }) : null);
    this.frameCount = 0;
    this.phaseTimer = null;
    this.lastExitSide = null; // "top" or "bottom" — tracks where ball exited
    this.audio = new BreakoutAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.mode === "solo") {
      this.peerReady = true;
      this._invalidate();
    } else if (this.isHost) {
      // Host waits for peer GAME_READY, then starts countdown
      this._invalidate();
    } else {
      // Peer sends ready signal
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
    this.localInputs = { left: false, right: false };
    this.remoteInputs = { left: false, right: false };
    this.peerReady = false;
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
            const prevPhase = this.gameState.phase;
            const prevScore = this.gameState.score;
            const prevLives = this.gameState.lives;

            // Apply decoded state, reconstruct blocks from bitmap
            this._ingestSnapshot(decoded, () => this._applyPeerState(decoded));
            this.setKeyboardCaptured(
              decoded.phase !== PHASE.WAITING && decoded.phase !== PHASE.FINISHED,
            );
            this._playPhaseAudio(prevPhase, decoded.phase, prevScore, prevLives);
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
          this.gameState.phase = PHASE.FINISHED;
          this.gameState.won = result.won;
          this.gameState.score = result.score;
          if (result.won) {
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

  /** Apply decoded peer state from host, reconstructing blocks alive status. */
  _applyPeerState(decoded) {
    this.gameState.ballX = decoded.ballX;
    this.gameState.ballY = decoded.ballY;
    this.gameState.ballVX = decoded.ballVX;
    this.gameState.ballVY = decoded.ballVY;
    this.gameState.paddle1X = decoded.paddle1X;
    this.gameState.paddle2X = decoded.paddle2X;
    this.gameState.score = decoded.score;
    this.gameState.lives = decoded.lives;
    this.gameState.phase = decoded.phase;
    this.gameState.countdown = decoded.countdown;
    this.gameState.blocksRemaining = decoded.blocksRemaining;

    // Update block alive status from bitmap
    if (decoded.blocksAlive && this.gameState.blocks) {
      for (let i = 0; i < this.gameState.blocks.length; i++) {
        this.gameState.blocks[i].alive = decoded.blocksAlive[i] || false;
      }
    }
  }

  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    if (keyCode === INPUT_KEY.LEFT) this.localInputs.left = true;
    if (keyCode === INPUT_KEY.RIGHT) this.localInputs.right = true;
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    if (keyCode === INPUT_KEY.LEFT) this.localInputs.left = false;
    if (keyCode === INPUT_KEY.RIGHT) this.localInputs.right = false;
  }

  /** Map keyboard key to INPUT_KEY enum. */
  _mapKey(key) {
    if (key === "ArrowLeft" || key === "a" || key === "A") return INPUT_KEY.LEFT;
    if (key === "ArrowRight" || key === "d" || key === "D") return INPUT_KEY.RIGHT;
    return null;
  }

  /** Clear all inputs on window blur (prevents stuck keys). */
  _handleBlur() {
    this.localInputs = { left: false, right: false };
    this._sendInputState();
  }

  beginMatch(options = {}) {
    if (!this.running || !this.isHost || this.gameState.phase !== PHASE.WAITING) return false;

    if (options.difficulty) {
      this.difficulty = normalizeBreakoutAIDifficulty(options.difficulty);
      if (
        !options.opponentController &&
        typeof this.opponentController?.setDifficulty === "function"
      ) {
        this.opponentController.setDifficulty(this.difficulty);
      }
    }
    if (options.opponentController) this.opponentController = options.opponentController;
    if (this.mode === "solo" && !this.opponentController) {
      this.opponentController = createBreakoutAI({ difficulty: this.difficulty });
    }

    this.setKeyboardCaptured(true);
    this.peerReady = true;
    this._startCountdown();
    return true;
  }

  /** Host: start countdown phase. */
  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this.setKeyboardCaptured(true);
    this._broadcastState();
    this.audio.playCountdown();

    let count = 3;
    const tick = () => {
      count--;
      if (count > 0) {
        this.gameState.countdown = count;
        this._broadcastState();
        this._invalidate();
        this.audio.playCountdown();
        this.phaseTimer = setTimeout(tick, 1000);
      } else {
        this._startServing();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  /** Host: transition to serving phase. */
  _startServing() {
    this.gameState.phase = PHASE.SERVING;
    this.gameState.countdown = 0;
    this.setKeyboardCaptured(true);
    this._broadcastState();
    this._invalidate();

    this.phaseTimer = setTimeout(() => {
      if (!this.running || !this.gameState) return;
      // Serve toward opposite side of last exit, or random for first serve
      let direction;
      if (this.lastExitSide === "bottom") {
        direction = -1; // serve upward (toward P2)
      } else if (this.lastExitSide === "top") {
        direction = 1; // serve downward (toward P1)
      } else {
        direction = Math.random() < 0.5 ? 1 : -1;
      }
      this.gameState = serveBall(this.gameState, direction);
      this._broadcastState();
      this._startGameLoop();
    }, SERVE_DELAY);
  }

  /** Host: start the main game loop. */
  _startGameLoop() {
    this.frameCount = 0;
    this._startSteps();
  }

  /** Host: main game loop (60Hz via requestAnimationFrame). */
  _gameLoop() {
    if (!this.isHost || !this.running || !this.gameState) return;

    this._updateOpponentInputs();

    // Update paddles (host = P1 bottom, peer = P2 top)
    this.gameState = updatePaddle(this.gameState, 1, this.localInputs);
    this.gameState = updatePaddle(this.gameState, 2, this.remoteInputs);

    // Update ball physics
    this.gameState = updateBall(this.gameState);
    this.gameState = checkWallBounce(this.gameState);

    if (this.gameState.wallBounced) {
      this.audio.playWallBounce();
      this.gameState.wallBounced = false;
    }

    this.gameState = checkPaddleCollision(this.gameState);

    if (this.gameState.paddleHit) {
      this.audio.playPaddleHit();
      this.gameState.paddleHit = false;
    }

    this.gameState = checkBlockCollision(this.gameState);

    if (this.gameState.blockHit) {
      this.audio.playBlockHit(this.gameState.hitBlockRow);
      this.gameState.particles = [
        ...(this.gameState.particles || []),
        ...createBlockParticles(
          this.gameState.hitBlockX,
          this.gameState.hitBlockY,
          this.gameState.hitBlockColor,
        ),
      ];
      this.gameState.blockHit = false;
    }

    // Check life lost (ball exits top or bottom)
    this.gameState = checkLifeLost(this.gameState);

    if (this.gameState.lifeLost) {
      this.audio.playLifeLost();
      // Track which side the ball exited for serve direction
      this.lastExitSide = this.gameState.ballY <= 0 + BALL_SIZE / 2 ? "top" : "bottom";
      this.gameState.lifeLost = false;
    }

    // Check win/lose
    this.gameState = checkWin(this.gameState);

    // Update particles
    if (this.gameState.particles && this.gameState.particles.length > 0) {
      this.gameState.particles = updateParticles(this.gameState.particles);
    }

    // Render
    this._invalidate();

    // Send state to peer
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    // Handle phase transitions
    if (this.gameState.phase === PHASE.FINISHED) {
      this._handleGameFinished();
      return;
    }

    if (this.gameState.phase === PHASE.LIFE_LOST && !this.phaseTimer) {
      // Schedule serve after pause (only once)
      this.phaseTimer = setTimeout(() => {
        this.phaseTimer = null;
        this._startServing();
      }, LIFE_LOST_PAUSE);
    }
  }

  /** Host: handle game end. */
  _handleGameFinished() {
    this._stopSteps();
    this.setKeyboardCaptured(false);
    const { score, won } = this.gameState;

    if (won) {
      this.audio.playWin();
    } else {
      this.audio.playLose();
    }

    // Send game end to peer
    this._sendCommand(encodeGameEnd(score, won));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: score, p2: score },
        winner: won ? 0 : -1, // 0 = both win (co-op), -1 = both lose
      });
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    this._stopSteps();
    this.setKeyboardCaptured(false);
    if (!this.gameState || this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this._invalidate();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.score, p2: this.gameState.score },
          winner: -1,
          disconnected: true,
        });
      } catch (error) {
        // The disconnect result callback (pushEvent) threw — do not lose it.
        log.debug("[GameEngine] game-end callback failed", error);
      }
    }
  }

  /** Send game state over DataChannel. */
  _broadcastState() {
    this._sendState(encodeGameState(this.gameState));
  }

  /** Render current state to canvas. */
  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, performance.now());
    }
  }

  _updateOpponentInputs() {
    if (this.mode !== "solo" || typeof this.opponentController?.nextInputs !== "function") return;

    const nextInputs = this.opponentController.nextInputs({
      state: this.gameState,
      player: 2,
      difficulty: this.difficulty,
    });

    this.remoteInputs = {
      left: nextInputs?.left === true,
      right: nextInputs?.right === true,
    };
  }

  _shouldPreventDefaultForCapturedKey(event) {
    return BREAKOUT_PREVENT_DEFAULT_KEYS.has(event.key);
  }

  /** Play audio based on phase transitions (peer side). */
  _playPhaseAudio(prevPhase, newPhase, prevScore, _prevLives) {
    if (prevPhase !== newPhase) {
      if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
      if (newPhase === PHASE.FINISHED) {
        if (this.gameState.won) {
          this.audio.playWin();
        } else {
          this.audio.playLose();
        }
      }
      if (newPhase === PHASE.LIFE_LOST) this.audio.playLifeLost();
    }
    if (this.gameState.score !== prevScore) {
      this.audio.playBlockHit(0);
    }
  }
}
