/**
 * BreakoutEngine — extends GameEngine with Block Breakers co-op game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/breakout_engine
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
  checkBlockCollision,
  checkLifeLost,
  checkWin,
  serveBall,
  createBlockParticles,
  updateParticles,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { BreakoutAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Send state every N frames (~30Hz at 60fps)
const SERVE_DELAY = 800; // ms
const LIFE_LOST_PAUSE = 1500; // ms

export class BreakoutEngine extends GameEngine {
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
    this.remoteInputs = { left: false, right: false };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new BreakoutAudio();
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
            const prevScore = this.gameState.score;
            const prevLives = this.gameState.lives;

            // Apply decoded state, reconstruct blocks from bitmap
            this._applyPeerState(decoded);
            this._playPhaseAudio(prevPhase, decoded.phase, prevScore, prevLives);
            this._renderState();
          }
        }
        break;

      case MSG_TYPE.PLAYER_INPUT:
        if (this.isHost) {
          const input = decodePlayerInput(buf);
          if (input) {
            if (input.keyCode === INPUT_KEY.LEFT) {
              this.remoteInputs.left = input.pressed;
            } else if (input.keyCode === INPUT_KEY.RIGHT) {
              this.remoteInputs.right = input.pressed;
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
          this.gameState.won = result.won;
          this.gameState.score = result.score;
          if (result.won) {
            this.audio.playWin();
          } else {
            this.audio.playLose();
          }
          this._renderState();
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

  /** Override base key handling to send binary input on peer side. */
  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    if (keyCode === INPUT_KEY.LEFT) this.localInputs.left = true;
    if (keyCode === INPUT_KEY.RIGHT) this.localInputs.right = true;

    if (!this.isHost) {
      this.channel.send(encodePlayerInput(keyCode, true));
    }
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    if (keyCode === INPUT_KEY.LEFT) this.localInputs.left = false;
    if (keyCode === INPUT_KEY.RIGHT) this.localInputs.right = false;

    if (!this.isHost) {
      this.channel.send(encodePlayerInput(keyCode, false));
    }
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
    if (!this.isHost) {
      this.channel.send(encodePlayerInput(INPUT_KEY.LEFT, false));
      this.channel.send(encodePlayerInput(INPUT_KEY.RIGHT, false));
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
        ...createBlockParticles(this.gameState.hitBlockX, this.gameState.hitBlockY).map((p) => ({
          ...p,
          color: this.gameState.hitBlockColor,
        })),
      ];
      this.gameState.blockHit = false;
    }

    // Check life lost (ball exits top or bottom)
    this.gameState = checkLifeLost(this.gameState);

    if (this.gameState.lifeLost) {
      this.audio.playLifeLost();
      this.gameState.lifeLost = false;
    }

    // Check win/lose
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

    if (this.gameState.phase === PHASE.LIFE_LOST) {
      // Pause then serve again
      this.phaseTimer = setTimeout(() => {
        this._startServing();
      }, LIFE_LOST_PAUSE);
      return;
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  /** Host: handle game end. */
  _handleGameFinished() {
    const { score, won } = this.gameState;

    if (won) {
      this.audio.playWin();
    } else {
      this.audio.playLose();
    }

    // Send game end to peer
    this.channel.send(encodeGameEnd(score, won));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: score, p2: score },
        winner: won ? 0 : -1, // 0 = both win (co-op), -1 = both lose
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
