/**
 * PongEngine — extends GameEngine with Hex Pong game loop, physics, and rendering.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/pong_engine
 */

import { GameEngine, keymap } from "../../game_engine.js";
import { createPongAI, normalizePongAIDifficulty } from "./ai.js";
import {
  MSG_TYPE,
  PHASE,
  SNAPSHOT,
  GAME_END,
  encodeGameReady,
  getMessageType,
} from "./protocol.js";
import {
  createInitialState,
  updatePaddle,
  updateBall,
  checkWallBounce,
  checkPaddleCollision,
  checkScore,
  checkWin,
  serveBall,
  createScoreParticles,
  updateParticles,
  CANVAS_W,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { PongAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 1; // broadcast every fixed step (60Hz)
const SERVE_DELAY = 800; // ms
const SCORE_PAUSE = 1500; // ms
const PONG_PREVENT_DEFAULT_KEYS = new Set([
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  " ",
  "Spacebar",
  "w",
  "W",
  "a",
  "A",
  "s",
  "S",
  "d",
  "D",
]);

export class PongEngine extends GameEngine {
  static FINAL_PHASE = PHASE.FINISHED;

  static INPUT_BITS = { up: 0, down: 1 };

  static KEYMAP = keymap({
    up: ["ArrowUp", "w", "W"],
    down: ["ArrowDown", "s", "S"],
  });

  static INTERPOLATION = { keys: ["ballX", "ballY", "paddle1Y", "paddle2Y"] };

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
    this.localInputs = { up: false, down: false };
    this.remoteInputs = { up: false, down: false };
    this.difficulty = normalizePongAIDifficulty(options.difficulty);
    this.opponentController =
      options.opponentController ||
      (this.mode === "solo" ? createPongAI({ difficulty: this.difficulty }) : null);
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new PongAudio();
    this.colors = null;
    this.peerReady = false;
  }

  start() {
    if (this.running) return;
    super.start();
    this.colors = getColors(this.canvas);

    if (this.mode === "solo") {
      this.peerReady = true;
      this._invalidate();
    } else if (this.isHost) {
      // Host waits for peer GAME_READY, then starts countdown
      this._invalidate();
    } else {
      // The host engine may still be loading lazily, so the base keeps
      // advertising readiness until the host answers.
      this._advertiseReady(encodeGameReady);
      this._invalidate();
    }
  }

  beginMatch(options = {}) {
    if (!this.running || !this.isHost || this.gameState.phase !== PHASE.WAITING) return false;

    if (options.difficulty) {
      this.difficulty = normalizePongAIDifficulty(options.difficulty);
      if (
        !options.opponentController &&
        typeof this.opponentController?.setDifficulty === "function"
      ) {
        this.opponentController.setDifficulty(this.difficulty);
      }
    }
    if (options.opponentController) this.opponentController = options.opponentController;
    if (this.mode === "solo" && !this.opponentController) {
      this.opponentController = createPongAI({ difficulty: this.difficulty });
    }

    this.setKeyboardCaptured(true);
    this.peerReady = true;
    this._startCountdown();
    return true;
  }

  _handleMessage(event) {
    if (!(event.data instanceof ArrayBuffer)) return;
    const buf = event.data;
    const type = getMessageType(buf);
    if (type === null) return;

    switch (type) {
      case MSG_TYPE.GAME_STATE:
        if (!this.isHost) {
          const decoded = SNAPSHOT.decode(buf);
          if (decoded) {
            const prevPhase = this.gameState.phase;
            const prevScore1 = this.gameState.score1;
            const prevScore2 = this.gameState.score2;

            this._ingestSnapshot(decoded);
            this.setKeyboardCaptured(
              decoded.phase !== PHASE.WAITING && decoded.phase !== PHASE.FINISHED,
            );
            this._playPhaseAudio(prevPhase, decoded.phase, prevScore1, prevScore2);
          }
        }
        break;

      case MSG_TYPE.GAME_READY:
        if (this.isHost && !this.peerReady) {
          this.beginMatch();
        }
        break;

      case MSG_TYPE.GAME_END: {
        const result = GAME_END.decode(buf);
        if (result) {
          this.setKeyboardCaptured(false);
          this.gameState.phase = PHASE.FINISHED;
          this.gameState.winner = result.winner;
          this.gameState.score1 = result.score1;
          this.gameState.score2 = result.score2;
          this.audio.playWin();
          this._invalidate();
        }
        break;
      }
    }
  }

  /** Host: start countdown phase. */
  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._invalidate();
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
    this._broadcastState();
    this._invalidate();

    this.phaseTimer = setTimeout(() => {
      this.gameState = serveBall(this.gameState);
      this._broadcastState();
      this._startGameLoop();
    }, SERVE_DELAY);
  }

  /** Host: start the main game loop. */
  _startGameLoop() {
    this.frameCount = 0;
    this._startSteps();
  }

  /** Host: one simulation step, driven at a fixed 60Hz by the frame clock. */
  _gameLoop() {
    if (!this.running) return;

    this._updateOpponentInputs();

    // Update paddles
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

    this.gameState = checkScore(this.gameState);

    if (this.gameState.scored) {
      this.audio.playScore();
      const particleX = this.gameState.lastScorer === 1 ? CANVAS_W - 20 : 20;
      this.gameState.particles = createScoreParticles(particleX, this.gameState.ballY);
      this.gameState.scored = false;
    }

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
      this._stopSteps();
      this._handleGameFinished();
      return;
    }

    if (this.gameState.phase === PHASE.SCORED) {
      // Pause then serve again
      this._stopSteps();
      this.phaseTimer = setTimeout(() => {
        this._startServing();
      }, SCORE_PAUSE);
    }
  }

  _updateOpponentInputs() {
    if (this.mode !== "solo" || typeof this.opponentController?.nextInputs !== "function") return;

    const nextInputs = this.opponentController.nextInputs({
      state: this.gameState,
      difficulty: this.difficulty,
      player: 2,
    });

    if (!nextInputs) return;

    this.remoteInputs = {
      up: nextInputs.up === true,
      down: nextInputs.down === true,
    };
  }

  /** Host: handle game end. */
  _handleGameFinished() {
    this._stopSteps();
    this.setKeyboardCaptured(false);
    const { score1, score2, winner } = this.gameState;
    this.audio.playWin();

    // The channel is unreliable, and no later message restates the result.
    this._sendCommand(GAME_END.encode({ score1, score2, winner }));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: score1, p2: score2 },
        winner: winner,
      });
    }
  }

  // ── Connection Resilience ──

  _disconnectResult() {
    return {
      score: { p1: this.gameState.score1, p2: this.gameState.score2 },
      winner: 0,
    };
  }

  /** Send game state over DataChannel. */
  _broadcastState() {
    this._sendState(SNAPSHOT.encode(this.gameState));
  }

  /** Render current state to canvas. */
  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, performance.now(), { mode: this.mode });
    }
  }

  _shouldPreventDefaultForCapturedKey(event) {
    return PONG_PREVENT_DEFAULT_KEYS.has(event.key);
  }

  /** Play audio based on phase transitions (peer side). */
  _playPhaseAudio(prevPhase, newPhase, prevScore1, prevScore2) {
    if (prevPhase !== newPhase) {
      if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
      if (newPhase === PHASE.FINISHED) this.audio.playWin();
    }
    if (this.gameState.score1 !== prevScore1 || this.gameState.score2 !== prevScore2) {
      this.audio.playScore();
    }
  }
}
