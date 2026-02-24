/**
 * WarlordEngine — extends GameEngine with Hex Warlords versus game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/warlords_engine
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

const STATE_SEND_INTERVAL = 2; // Send state every N frames (~30Hz at 60fps)
const SERVE_DELAY = 800; // ms
const KING_HIT_PAUSE = 2000; // ms

export class WarlordEngine extends GameEngine {
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
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
  }

  start() {
    super.start();
    this.localInputs = { up: false, down: false, space: false };
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);

    if (this.isHost) {
      this._renderState();
    } else {
      this._safeSend(encodeGameReady());
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
            this._applyPeerState(decoded);
            this._playPhaseAudio(prevPhase, decoded.phase);
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
            } else if (input.keyCode === INPUT_KEY.SPACE) {
              // Peer released space while holding fireball → release
              if (!input.pressed && this.gameState.caughtBy === 2) {
                this.gameState = releaseBall(this.gameState, 2);
                if (this.gameState.released) {
                  this.audio.playLaunch();
                  this.gameState.released = false;
                }
              }
              this.remoteInputs.space = input.pressed;
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
          this._renderState();
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

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(keyCode, true));
    }
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

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(keyCode, false));
    }
  }

  /** Map keyboard key to INPUT_KEY enum. */
  _mapKey(key) {
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.UP;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.DOWN;
    if (key === " ") return INPUT_KEY.SPACE;
    return null;
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

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.UP, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.DOWN, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.SPACE, false));
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

  /** Host: transition to serving phase then start game loop. */
  _startServing() {
    // Reset fireball to center without velocity — actual serve happens after delay
    this.gameState.fireballX = CANVAS_W / 2;
    this.gameState.fireballY = CANVAS_H / 2;
    this.gameState.fireballVX = 0;
    this.gameState.fireballVY = 0;
    this.gameState.caughtBy = 0;
    this._broadcastState();
    this._renderState();

    this.phaseTimer = setTimeout(() => {
      this.gameState = serveFireball(this.gameState);
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
    this._renderState();

    // Send state to peer
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  /** Host: handle king hit — pause, check game over, rebuild or finish. */
  _handleKingHit() {
    this.gameState.phase = PHASE.KING_HIT;
    this._broadcastState();
    this._renderState();

    // Keep rendering particles during pause
    const renderDuringPause = () => {
      if (!this.running || this.gameState.phase !== PHASE.KING_HIT) return;
      if (this.gameState.particles && this.gameState.particles.length > 0) {
        this.gameState.particles = updateParticles(this.gameState.particles);
      }
      this._renderState();
      this.animFrame = requestAnimationFrame(renderDuringPause);
    };
    this.animFrame = requestAnimationFrame(renderDuringPause);

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
    const { p1Lives, p2Lives, winner } = this.gameState;

    // Host determines if they won
    const hostWon = winner === 1;
    if (hostWon) {
      this.audio.playWin();
    } else {
      this.audio.playLose();
    }

    // Send game end to peer
    this._safeSend(encodeGameEnd(p1Lives, p2Lives, winner));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: p1Lives, p2: p2Lives },
        winner,
      });
    }
  }

  /** Send game state over DataChannel. */
  _broadcastState() {
    this._safeSend(encodeGameState(this.gameState));
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
