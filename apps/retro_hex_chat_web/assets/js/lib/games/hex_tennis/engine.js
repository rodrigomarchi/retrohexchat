/**
 * TennisEngine — extends GameEngine with Hex Tennis game loop, physics, and rendering.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/hex_tennis/engine
 */
import { log } from "../../logger.js";

import { GameEngine } from "../../game_engine.js";
import { createTennisAI, normalizeTennisAIDifficulty } from "./ai.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  encodeGameState,
  decodeGameState,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "./protocol.js";
import {
  createInitialState,
  updatePlayer,
  updateBall,
  checkHitZone,
  checkNetCollision,
  checkOutOfBounds,
  performServe,
  checkServeLanding,
  advanceScore,
  shouldChangeover,
  resetForNextPoint,
  clearEventFlags,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { TennisAudio } from "./audio.js";

const MODE_MAP = {
  hex_tennis: GAME_MODE.CLASSIC,
  hex_tennis_quick: GAME_MODE.QUICK,
  hex_tennis_sudden: GAME_MODE.SUDDEN_DEATH,
};

const STATE_SEND_INTERVAL = 1; // broadcast every fixed step (60Hz)
const POINT_PAUSE_FRAMES = 120; // 2s at 60fps
const CHANGEOVER_PAUSE_FRAMES = 120; // 2s
const TENNIS_PREVENT_DEFAULT_KEYS = new Set([
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

/**
 * @param {string} gameId
 * @returns {number}
 */
function gameModeFromId(gameId) {
  return MODE_MAP[gameId] ?? GAME_MODE.CLASSIC;
}

export class TennisEngine extends GameEngine {
  static INPUT_BITS = { up: 0, down: 1, left: 2, right: 3, serve: 4 };

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
    this.gameMode = gameModeFromId(gameId);
    this.gameState = createInitialState(this.gameMode);
    this.localInputs = { up: false, down: false, left: false, right: false, serve: false };
    this.remoteInputs = { up: false, down: false, left: false, right: false, serve: false };
    this._localServePressed = false;
    this._remoteServePressed = false;
    this.frameCount = 0;
    this.phaseTimer = null;
    this.pointPauseCounter = 0;
    this.audio = new TennisAudio();
    this.colors = null;
    this.peerReady = false;
    this.difficulty = normalizeTennisAIDifficulty(options.difficulty);
    this.opponentController =
      options.opponentController ||
      (this.mode === "solo" ? createTennisAI({ difficulty: this.difficulty }) : null);
    this._prevPeerFlags = {
      hitEvent: false,
      serveEvent: false,
      faultEvent: false,
      netFault: false,
      outOfBounds: false,
    };
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
      this._invalidate();
    } else {
      this._advertiseReady(encodeGameReady);
      this._invalidate();
    }
  }

  stop() {
    super.stop();
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }
    this._localServePressed = false;
    this._remoteServePressed = false;
  }

  beginMatch(options = {}) {
    if (!this.running || !this.isHost || this.gameState.phase !== PHASE.WAITING) return false;

    if (options.difficulty) {
      this.difficulty = normalizeTennisAIDifficulty(options.difficulty);
      if (
        !options.opponentController &&
        typeof this.opponentController?.setDifficulty === "function"
      ) {
        this.opponentController.setDifficulty(this.difficulty);
      }
    }
    if (options.opponentController) this.opponentController = options.opponentController;
    if (this.mode === "solo" && !this.opponentController) {
      this.opponentController = createTennisAI({ difficulty: this.difficulty });
    }

    this.setKeyboardCaptured(true);
    this.peerReady = true;
    this._startCountdown();
    return true;
  }

  // ── Input Handling ──

  _mapKey(key) {
    switch (key) {
      case "ArrowUp":
      case "w":
      case "W":
        return INPUT_KEY.UP;
      case "ArrowDown":
      case "s":
      case "S":
        return INPUT_KEY.DOWN;
      case "ArrowLeft":
      case "a":
      case "A":
        return INPUT_KEY.LEFT;
      case "ArrowRight":
      case "d":
      case "D":
        return INPUT_KEY.RIGHT;
      case " ":
      case "Shift":
        return INPUT_KEY.SERVE;
      default:
        return null;
    }
  }

  _handleKeyDown(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (k === INPUT_KEY.UP) this.localInputs.up = true;
    else if (k === INPUT_KEY.DOWN) this.localInputs.down = true;
    else if (k === INPUT_KEY.LEFT) this.localInputs.left = true;
    else if (k === INPUT_KEY.RIGHT) this.localInputs.right = true;
    else if (k === INPUT_KEY.SERVE) this.localInputs.serve = true;
  }

  _handleKeyUp(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (k === INPUT_KEY.UP) this.localInputs.up = false;
    else if (k === INPUT_KEY.DOWN) this.localInputs.down = false;
    else if (k === INPUT_KEY.LEFT) this.localInputs.left = false;
    else if (k === INPUT_KEY.RIGHT) this.localInputs.right = false;
    else if (k === INPUT_KEY.SERVE) this.localInputs.serve = false;
  }

  _handleBlur() {
    this.localInputs = { up: false, down: false, left: false, right: false, serve: false };
    this._sendInputState();
  }

  // ── Network Messages ──

  _handleMessage(event) {
    const buf = event.data;
    if (!(buf instanceof ArrayBuffer)) return;
    const type = getMessageType(buf);
    if (type === null) return;

    switch (type) {
      case MSG_TYPE.GAME_STATE:
        if (!this.isHost) {
          const decoded = decodeGameState(buf);
          if (decoded) {
            this._ingestSnapshot(decoded, () => this._applyPeerState(decoded));
            this.setKeyboardCaptured(
              decoded.phase !== PHASE.WAITING && decoded.phase !== PHASE.GAME_OVER,
            );
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
          this.gameState.phase = PHASE.GAME_OVER;
          this.gameState.winner = result.winner;
          this.gameState.p1Games = result.p1Games;
          this.gameState.p2Games = result.p2Games;
          this.audio.playMatchWon();
          this._invalidate();
          if (this.onGameEnd) {
            try {
              this.onGameEnd({
                score: { p1: result.p1Games, p2: result.p2Games },
                winner: result.winner,
              });
            } catch (error) {
              // The disconnect result callback (pushEvent) threw — do not lose it.
              log.debug("[GameEngine] game-end callback failed", error);
            }
          }
        }
        break;
      }
    }
  }

  // ── Countdown ──

  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._invalidate();

    let count = 3;
    const tick = () => {
      if (!this.running) return;
      this.audio.playCountdown();
      count--;
      if (count <= 0) {
        this.gameState.phase = PHASE.SERVING;
        this.gameState.countdown = 0;
        this._broadcastState();
        this._invalidate();
        this._startGameLoop();
      } else {
        this.gameState.countdown = count;
        this._broadcastState();
        this._invalidate();
        this.phaseTimer = setTimeout(tick, 1000);
      }
    };

    this.phaseTimer = setTimeout(tick, 1000);
  }

  _startGameLoop() {
    this.frameCount = 0;
    this._startSteps();
  }

  // ── Game Loop (Host Only) ──

  _gameLoop() {
    if (!this.running) return;
    let s = this.gameState;

    this._updateOpponentInputs();

    if (s.phase === PHASE.SERVING) {
      // Update players during serve phase
      s = updatePlayer(s, 1, this.localInputs);
      s = updatePlayer(s, 2, this.remoteInputs);

      // Edge-triggered serve (host local — only when P1 is server)
      if (this.localInputs.serve && !this._localServePressed && s.server === 1) {
        s = performServe(s);
        this.audio.playServe();
      }
      this._localServePressed = this.localInputs.serve;

      // Edge-triggered serve (remote)
      if (this.remoteInputs.serve && !this._remoteServePressed) {
        if (s.server === 2) {
          s = performServe(s);
          this.audio.playServe();
        }
      }
      this._remoteServePressed = this.remoteInputs.serve;

      // Serve timer countdown (only if serve wasn't already triggered)
      if (s.phase === PHASE.SERVING) {
        s = { ...s, serveTimer: s.serveTimer - 1 };
        if (s.serveTimer <= 0) {
          s = performServe(s);
          this.audio.playServe();
        }
      }

      this.gameState = s;
    } else if (s.phase === PHASE.RALLY) {
      s = clearEventFlags(s);

      // Update players
      s = updatePlayer(s, 1, this.localInputs);
      s = updatePlayer(s, 2, this.remoteInputs);

      // Update ball
      s = updateBall(s);

      // Check hit zones
      s = checkHitZone(s, 1);
      s = checkHitZone(s, 2);

      if (s.hitEvent && !this.gameState.hitEvent) {
        this.audio.playHit();
      }

      // Check serve landing (first bounce)
      s = checkServeLanding(s);

      if (s.faultEvent && !this.gameState.faultEvent) {
        this.audio.playFault();
        if (s.phase === PHASE.SERVING) {
          // First serve fault → back to serving
          this.gameState = s;
          this._invalidate();
          this.frameCount++;
          if (this.frameCount % STATE_SEND_INTERVAL === 0) {
            this._broadcastState();
          }
          return;
        }
      }

      // Check net collision
      s = checkNetCollision(s);
      if (s.netFault && !this.gameState.netFault) {
        this.audio.playNetHit();
      }

      // Check out of bounds
      s = checkOutOfBounds(s);
      if (s.outOfBounds && !this.gameState.outOfBounds) {
        if (s.outType === 3) {
          this.audio.playAce();
        } else {
          this.audio.playOut();
        }
      }

      // Score point if someone won it
      if (s.pointWinner > 0) {
        s = advanceScore(s);
        this.audio.playPoint();

        if (s.phase === PHASE.GAME_OVER) {
          this.gameState = s;
          this._handleGameFinished();
          return;
        }

        // Transition to POINT pause
        s.phase = PHASE.POINT;
        this.pointPauseCounter = POINT_PAUSE_FRAMES;
        this.gameState = s;
        this._invalidate();
        this._broadcastState();
        return;
      }

      this.gameState = s;
    } else if (s.phase === PHASE.POINT) {
      this.pointPauseCounter--;
      if (this.pointPauseCounter <= 0) {
        // Check changeover
        if (shouldChangeover(s)) {
          s.phase = PHASE.CHANGEOVER;
          this.pointPauseCounter = CHANGEOVER_PAUSE_FRAMES;
          this.gameState = s;
        } else {
          this.gameState = resetForNextPoint(s);
        }
      }
    } else if (s.phase === PHASE.CHANGEOVER) {
      this.pointPauseCounter--;
      if (this.pointPauseCounter <= 0) {
        this.gameState = resetForNextPoint(s);
      }
    }

    // Render
    this._invalidate();

    // Broadcast
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    // Check game over
    if (this.gameState.phase === PHASE.GAME_OVER) {
      this._handleGameFinished();
      return;
    }
  }

  // ── Game End ──

  _handleGameFinished() {
    this._stopSteps();
    this.setKeyboardCaptured(false);
    const { p1Games, p2Games, winner, gameMode, isTiebreak } = this.gameState;

    this._broadcastState();
    this._invalidate();

    this._sendCommand(encodeGameEnd(p1Games, p2Games, winner, gameMode, isTiebreak));

    if (winner > 0) {
      this.audio.playMatchWon();
    }

    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: p1Games, p2: p2Games },
          winner,
        });
      } catch (error) {
        // The disconnect result callback (pushEvent) threw — do not lose it.
        log.debug("[GameEngine] game-end callback failed", error);
      }
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    this._stopSteps();
    this.setKeyboardCaptured(false);
    if (this.gameState.phase === PHASE.GAME_OVER) return;
    this.gameState.phase = PHASE.GAME_OVER;
    this._invalidate();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.p1Games, p2: this.gameState.p2Games },
          winner: 0,
        });
      } catch (error) {
        // The disconnect result callback (pushEvent) threw — do not lose it.
        log.debug("[GameEngine] game-end callback failed", error);
      }
    }
  }

  // ── Rendering ──

  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, performance.now());
    }
  }

  // ── State Broadcasting ──

  /** Flatten ball object for protocol encoding. */
  _flattenStateForEncode() {
    const s = this.gameState;
    return {
      ...s,
      ballX: s.ball.x,
      ballY: s.ball.y,
      ballVX: s.ball.vx,
      ballVY: s.ball.vy,
      ballHeight: s.ball.height,
    };
  }

  _broadcastState() {
    this._sendState(encodeGameState(this._flattenStateForEncode()));
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
      left: nextInputs.left === true,
      right: nextInputs.right === true,
      serve: nextInputs.serve === true,
    };
  }

  _shouldPreventDefaultForCapturedKey(event) {
    return TENNIS_PREVENT_DEFAULT_KEYS.has(event.key);
  }

  // ── Peer Audio ──

  _applyPeerState(decoded) {
    const prevPhase = this.gameState.phase;
    this.gameState = {
      ...this.gameState,
      ...decoded,
      ball: {
        x: decoded.ballX,
        y: decoded.ballY,
        vx: decoded.ballVX,
        vy: decoded.ballVY,
        speed: this.gameState.ball ? this.gameState.ball.speed : 0,
        height: decoded.ballHeight,
        heightVel: this.gameState.ball ? this.gameState.ball.heightVel : 0,
      },
    };
    this._playPeerAudio(prevPhase, decoded.phase);
  }

  _playPeerAudio(prevPhase, newPhase) {
    if (prevPhase !== newPhase) {
      if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
      if (newPhase === PHASE.GAME_OVER) this.audio.playMatchWon();
      if (newPhase === PHASE.POINT) this.audio.playPoint();
    }

    // Gameplay event sounds — edge detection (only on rising edge)
    const s = this.gameState;
    const prev = this._prevPeerFlags;

    if (s.hitEvent && !prev.hitEvent) this.audio.playHit();
    if (s.serveEvent && !prev.serveEvent) this.audio.playServe();
    if (s.faultEvent && !prev.faultEvent) this.audio.playFault();
    if (s.netFault && !prev.netFault) this.audio.playNetHit();
    if (s.outOfBounds && !prev.outOfBounds) {
      if (s.outType === 3) this.audio.playAce();
      else this.audio.playOut();
    }

    this._prevPeerFlags = {
      hitEvent: s.hitEvent,
      serveEvent: s.serveEvent,
      faultEvent: s.faultEvent,
      netFault: s.netFault,
      outOfBounds: s.outOfBounds,
    };
  }
}
