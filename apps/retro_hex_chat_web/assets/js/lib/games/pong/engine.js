/**
 * PongEngine — extends GameEngine with Hex Pong game loop, physics, and rendering.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/pong_engine
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
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

const STATE_SEND_INTERVAL = 2; // Send state every N frames (~30Hz at 60fps)
const SERVE_DELAY = 800; // ms
const SCORE_PAUSE = 1500; // ms

export class PongEngine extends GameEngine {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {function} onGameEnd - callback when game finishes
   */
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd || null;
    this.gameState = createInitialState();
    this.remoteInputs = { up: false, down: false };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new PongAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
  }

  start() {
    super.start();
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);

    if (this.isHost) {
      // Host waits for peer GAME_READY, then starts countdown
      this._renderState();
    } else {
      // Peer sends ready signal
      this.channel.send(encodeGameReady());
      this._renderState();
    }
  }

  stop() {
    window.removeEventListener("blur", this._boundBlur);
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }
    if (this.animFrame) {
      cancelAnimationFrame(this.animFrame);
      this.animFrame = null;
    }
    this.running = false;
    // Call parent stop for event listener cleanup
    this.channel.removeEventListener("message", this._boundOnMessage);
    document.removeEventListener("keydown", this._boundOnKeyDown);
    document.removeEventListener("keyup", this._boundOnKeyUp);
  }

  /** Override base engine message handler to use binary protocol. */
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
            const prevScore1 = this.gameState.score1;
            const prevScore2 = this.gameState.score2;

            this.gameState = { ...this.gameState, ...decoded };
            this._playPhaseAudio(prevPhase, decoded.phase, prevScore1, prevScore2);
            this._renderState();
          }
        }
        break;

      case MSG_TYPE.PLAYER_INPUT:
        if (this.isHost) {
          const input = decodePlayerInput(buf);
          if (input) {
            if (input.keyCode === INPUT_KEY.UP) {
              this.remoteInputs.up = input.pressed;
            } else if (input.keyCode === INPUT_KEY.DOWN) {
              this.remoteInputs.down = input.pressed;
            }
          }
        }
        break;

      case MSG_TYPE.GAME_READY:
        if (this.isHost && !this.peerReady) {
          this.peerReady = true;
          this._startCountdown();
        }
        break;

      case MSG_TYPE.GAME_END: {
        const result = decodeGameEnd(buf);
        if (result) {
          this.gameState.phase = PHASE.FINISHED;
          this.gameState.winner = result.winner;
          this.gameState.score1 = result.score1;
          this.gameState.score2 = result.score2;
          this.audio.playWin();
          this._renderState();
        }
        break;
      }
    }
  }

  /** Override base key handling to send binary input on peer side. */
  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    if (keyCode === INPUT_KEY.UP) this.localInputs.up = true;
    if (keyCode === INPUT_KEY.DOWN) this.localInputs.down = true;

    if (!this.isHost) {
      this.channel.send(encodePlayerInput(keyCode, true));
    }
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    if (keyCode === INPUT_KEY.UP) this.localInputs.up = false;
    if (keyCode === INPUT_KEY.DOWN) this.localInputs.down = false;

    if (!this.isHost) {
      this.channel.send(encodePlayerInput(keyCode, false));
    }
  }

  /** Map keyboard key to INPUT_KEY enum. */
  _mapKey(key) {
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.UP;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.DOWN;
    return null;
  }

  /** Clear all inputs on window blur (prevents stuck keys). */
  _handleBlur() {
    this.localInputs = { up: false, down: false };
    if (!this.isHost) {
      this.channel.send(encodePlayerInput(INPUT_KEY.UP, false));
      this.channel.send(encodePlayerInput(INPUT_KEY.DOWN, false));
    }
  }

  /** Host: start countdown phase. */
  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this.audio.playCountdown();

    let count = 3;
    const tick = () => {
      count--;
      if (count > 0) {
        this.gameState.countdown = count;
        this._broadcastState();
        this._renderState();
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
    this._renderState();

    this.phaseTimer = setTimeout(() => {
      this.gameState = serveBall(this.gameState);
      this._broadcastState();
      this._startGameLoop();
    }, SERVE_DELAY);
  }

  /** Host: start the main game loop. */
  _startGameLoop() {
    this.frameCount = 0;
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  /** Host: main game loop (60Hz via requestAnimationFrame). */
  _gameLoop(_timestamp) {
    if (!this.running) return;

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
    this._renderState();

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

    if (this.gameState.phase === PHASE.SCORED) {
      // Pause then serve again
      this.phaseTimer = setTimeout(() => {
        this._startServing();
      }, SCORE_PAUSE);
      return;
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  /** Host: handle game end. */
  _handleGameFinished() {
    const { score1, score2, winner } = this.gameState;
    this.audio.playWin();

    // Send game end to peer
    this.channel.send(encodeGameEnd(score1, score2, winner));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: score1, p2: score2 },
        winner: winner,
      });
    }
  }

  /** Send game state over DataChannel. */
  _broadcastState() {
    if (this.channel.readyState === "open") {
      this.channel.send(encodeGameState(this.gameState));
    }
  }

  /** Render current state to canvas. */
  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, performance.now());
    }
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
