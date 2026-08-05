/**
 * WarlordEngine — extends GameEngine with Hex Warlords versus game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/warlords_engine
 */
import { log } from "../../logger.js";

import { GameEngine } from "../../game_engine.js";
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
  createInitialState,
  updateShield,
  updateFireball,
  updateCaughtFireball,
  checkWallBounce,
  checkShieldCollision,
  checkCatch,
  releaseBall,
  checkBrickCollision,
  checkKingHit,
  checkGameOver,
  rebuildCastles,
  serveFireball,
  createBrickParticles,
  createKingParticles,
  updateParticles,
  P1_KING_X,
  P1_KING_Y,
  P2_KING_X,
  P2_KING_Y,
  CANVAS_W,
  CANVAS_H,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { WarlordAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 1; // broadcast every fixed step (60Hz)
const SERVE_DELAY = 800; // ms
const KING_HIT_PAUSE = 2000; // ms

export class WarlordEngine extends GameEngine {
  static INPUT_BITS = { up: 0, down: 1, space: 2 };

  static INTERPOLATION = {
    keys: ["fireballX", "fireballY", "shield1Y", "shield2Y"],
  };

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
    this.remoteInputs = { up: false, down: false, space: false };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new WarlordAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();
    this.localInputs = { up: false, down: false, space: false };
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.isHost) {
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
    super.stop();
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
            this._ingestSnapshot(decoded, () => this._applyPeerState(decoded));
            this._playPhaseAudio(prevPhase, decoded.phase);
            this._invalidate();
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
          this.gameState.p1Lives = result.p1Lives;
          this.gameState.p2Lives = result.p2Lives;
          this.gameState.winner = result.winner;
          // Peer determines if they won or lost
          const peerIsWinner = result.winner === 2;
          if (peerIsWinner) {
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

  /** Apply decoded peer state from host, reconstructing brick alive status. */
  _applyPeerState(decoded) {
    this.gameState.fireballX = decoded.fireballX;
    this.gameState.fireballY = decoded.fireballY;
    this.gameState.fireballVX = decoded.fireballVX;
    this.gameState.fireballVY = decoded.fireballVY;
    this.gameState.shield1Y = decoded.shield1Y;
    this.gameState.shield2Y = decoded.shield2Y;
    this.gameState.p1Lives = decoded.p1Lives;
    this.gameState.p2Lives = decoded.p2Lives;
    this.gameState.phase = decoded.phase;
    this.gameState.countdown = decoded.countdown;
    this.gameState.round = decoded.round;
    this.gameState.caughtBy = decoded.caughtBy;

    // Derive king alive status from lives (king is alive if player still has lives
    // AND we're not in KING_HIT phase for that player)
    this.gameState.p1KingAlive = decoded.p1Lives > 0;
    this.gameState.p2KingAlive = decoded.p2Lives > 0;

    // Derive kingHitPlayer for rendering: during KING_HIT phase, the player whose
    // king was hit has fewer lives than expected based on the current round context.
    // We can infer it: if phase is KING_HIT, the recently hit king is dead (KingAlive=false
    // is set by checkKingHit, but rebuild hasn't happened yet). However, since we derive
    // kingAlive from lives > 0, a player at 0 lives has kingAlive=false. For mid-game hits
    // (lives > 0), the king was set to false by host but we derive it as true from lives.
    // Better approach: encode kingHitPlayer in protocol via caughtBy-like mechanism.
    // For now, track it via a compact derivation: during KING_HIT, the hit player is
    // whichever player's lives decreased since last update.
    if (decoded.phase === PHASE.KING_HIT) {
      if (this._prevP1Lives !== undefined && decoded.p1Lives < this._prevP1Lives) {
        this.gameState.kingHitPlayer = 1;
        this.gameState.p1KingAlive = false;
      } else if (this._prevP2Lives !== undefined && decoded.p2Lives < this._prevP2Lives) {
        this.gameState.kingHitPlayer = 2;
        this.gameState.p2KingAlive = false;
      }
    }
    this._prevP1Lives = decoded.p1Lives;
    this._prevP2Lives = decoded.p2Lives;

    // Update brick alive status from bitmaps
    if (decoded.p1BricksAlive && this.gameState.p1Bricks) {
      for (let i = 0; i < this.gameState.p1Bricks.length; i++) {
        this.gameState.p1Bricks[i].alive = decoded.p1BricksAlive[i] || false;
      }
    }
    if (decoded.p2BricksAlive && this.gameState.p2Bricks) {
      for (let i = 0; i < this.gameState.p2Bricks.length; i++) {
        this.gameState.p2Bricks[i].alive = decoded.p2BricksAlive[i] || false;
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
    if (keyCode === INPUT_KEY.SPACE) this.localInputs.space = true;
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    if (keyCode === INPUT_KEY.UP) this.localInputs.up = false;
    if (keyCode === INPUT_KEY.DOWN) this.localInputs.down = false;
    if (keyCode === INPUT_KEY.SPACE) {
      this.localInputs.space = false;
      // Host released space while holding fireball → release
      if (this.isHost && this.gameState.caughtBy === 1) {
        this.gameState = releaseBall(this.gameState, 1);
        if (this.gameState.released) {
          this.audio.playLaunch();
          this.gameState.released = false;
        }
      }
    }
  }

  /** Map keyboard key to INPUT_KEY enum. */
  _mapKey(key) {
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.UP;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.DOWN;
    if (key === " ") return INPUT_KEY.SPACE;
    return null;
  }

  /**
   * Host: the guest launches a caught fireball by *releasing* space, so this
   * mechanic lives on the edge rather than on the key being held.
   * @param {Record<string, boolean>} previous
   * @param {Record<string, boolean>} current
   * @returns {void}
   */
  _onRemoteInputChange(previous, current) {
    if (!previous.space || current.space) return;
    if (this.gameState.caughtBy !== 2) return;

    this.gameState = releaseBall(this.gameState, 2);

    if (this.gameState.released) {
      this.audio.playLaunch();
      this.gameState.released = false;
    }
  }

  /** Clear all inputs on window blur. */
  _handleBlur() {
    this.localInputs = { up: false, down: false, space: false };

    // Host: release caught fireball on blur (otherwise it stays stuck)
    if (this.isHost && this.gameState.caughtBy === 1) {
      this.gameState = releaseBall(this.gameState, 1);
      if (this.gameState.released) {
        this.audio.playLaunch();
        this.gameState.released = false;
      }
    }
    this._sendInputState();
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
        this._invalidate();
        this.audio.playCountdown();
        this.phaseTimer = setTimeout(tick, 1000);
      } else {
        this._startServing();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  /** Host: transition to serving phase then start game loop. */
  _startServing() {
    // Reset fireball to center without velocity — actual serve happens after delay
    this.gameState.fireballX = CANVAS_W / 2;
    this.gameState.fireballY = CANVAS_H / 2;
    this.gameState.fireballVX = 0;
    this.gameState.fireballVY = 0;
    this.gameState.caughtBy = 0;
    this._broadcastState();
    this._invalidate();

    this.phaseTimer = setTimeout(() => {
      this.gameState = serveFireball(this.gameState);
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
    if (!this.running) return;

    // Update shields (host = P1, peer = P2)
    this.gameState = updateShield(this.gameState, 1, this.localInputs);
    this.gameState = updateShield(this.gameState, 2, this.remoteInputs);

    // Update caught fireball position to follow shield
    this.gameState = updateCaughtFireball(this.gameState);

    // Update fireball physics (skipped if caught)
    this.gameState = updateFireball(this.gameState);
    this.gameState = checkWallBounce(this.gameState);

    if (this.gameState.wallBounced) {
      this.audio.playWallBounce();
      this.gameState.wallBounced = false;
    }

    // Shield collision
    this.gameState = checkShieldCollision(this.gameState);

    if (this.gameState.shieldHit) {
      // Check for catch before deflection sound
      this.gameState = checkCatch(this.gameState, this.localInputs, this.remoteInputs);

      if (this.gameState.caught) {
        this.audio.playCatch();
        this.gameState.caught = false;
      } else {
        this.audio.playShieldDeflect();
      }
      this.gameState.shieldHit = false;
      this.gameState.shieldHitPlayer = 0;
    }

    // Brick collision
    this.gameState = checkBrickCollision(this.gameState);

    if (this.gameState.brickHit) {
      this.audio.playBrickHit();
      this.gameState.particles = [
        ...(this.gameState.particles || []),
        ...createBrickParticles(
          this.gameState.hitBrickX,
          this.gameState.hitBrickY,
          this.gameState.hitBrickColor,
        ),
      ];
      this.gameState.brickHit = false;
    }

    // King hit
    this.gameState = checkKingHit(this.gameState);

    if (this.gameState.kingHit) {
      this.audio.playKingHit();
      const kingX = this.gameState.kingHitPlayer === 1 ? P1_KING_X : P2_KING_X;
      const kingY = this.gameState.kingHitPlayer === 1 ? P1_KING_Y : P2_KING_Y;
      this.gameState.particles = [
        ...(this.gameState.particles || []),
        ...createKingParticles(kingX, kingY),
      ];
      this.gameState.kingHit = false;
      this._handleKingHit();
      return;
    }

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
  }

  /** Host: handle king hit — pause, check game over, rebuild or finish. */
  /** Let the castle debris settle while the round is paused on a king hit. */
  _idleStep() {
    if (this.gameState.phase !== PHASE.KING_HIT) return;
    if (!this.gameState.particles || !this.gameState.particles.length) return;
    this.gameState.particles = updateParticles(this.gameState.particles);
    this._invalidate();
  }

  _handleKingHit() {
    this.gameState.phase = PHASE.KING_HIT;
    this._broadcastState();
    this._invalidate();
    this._stopSteps();

    this.phaseTimer = setTimeout(() => {
      // Check game over
      this.gameState = checkGameOver(this.gameState);

      if (this.gameState.phase === PHASE.FINISHED) {
        this._handleGameFinished();
        return;
      }

      // Rebuild castles and start next round
      this.gameState = rebuildCastles(this.gameState);
      this._startCountdown();
    }, KING_HIT_PAUSE);
  }

  /** Host: handle game end. */
  _handleGameFinished() {
    this._stopSteps();
    const { p1Lives, p2Lives, winner } = this.gameState;

    // Host determines if they won
    const hostWon = winner === 1;
    if (hostWon) {
      this.audio.playWin();
    } else {
      this.audio.playLose();
    }

    // Send game end to peer
    this._sendCommand(encodeGameEnd(p1Lives, p2Lives, winner));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: p1Lives, p2: p2Lives },
        winner,
      });
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    this._stopSteps();
    if (!this.gameState || this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this._invalidate();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.p1Lives, p2: this.gameState.p2Lives },
          winner: 0,
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

  /** Play audio based on phase transitions (peer side). */
  _playPhaseAudio(prevPhase, newPhase) {
    if (prevPhase === newPhase) return;
    if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
    if (newPhase === PHASE.KING_HIT) this.audio.playKingHit();
  }
}
