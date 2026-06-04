/**
 * SurroundEngine — extends GameEngine with Light Trails (Tron) game loop.
 * Host-authoritative: creator runs tick-based physics, peer receives state.
 * Two-loop design: 10Hz physics ticks + 60fps rendering.
 * @module games/surround_engine
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  WINS_NEEDED,
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
  moveAndCheck,
  createCrashParticles,
  updateParticles,
  CELL,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { SurroundAudio } from "./audio.js";
import { gameColor } from "../../game_colors.js";

const TICK_INTERVAL = 100; // 10Hz — discrete grid movement
const ROUND_OVER_DELAY = 3000; // ms before next round

export class SurroundEngine extends GameEngine {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {function} onGameEnd - callback when match finishes
   */
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd || null;
    this.gameState = createInitialState(0);
    this.p1PendingDir = this.gameState.p1.dir;
    this.p2PendingDir = this.gameState.p2.dir;
    this.tickInterval = null;
    this.animFrame = null;
    this.phaseTimer = null;
    this.audio = new SurroundAudio();
    this.colors = null;
    this.peerReady = false;
    this._savedScores = { score1: 0, score2: 0 };
    this._boundRenderLoop = this._renderLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    // Start render loop immediately (shows waiting screen)
    this.animFrame = requestAnimationFrame(this._boundRenderLoop);

    if (!this.isHost) {
      // Peer sends ready signal
      this._safeSend(encodeGameReady());
    }
  }

  stop() {
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    this._stopTickLoop();
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }
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
            this._applyPeerState(decoded);
          }
        }
        break;

      case MSG_TYPE.PLAYER_INPUT:
        if (this.isHost) {
          const input = decodePlayerInput(buf);
          if (input && input.pressed && input.keyCode >= 0 && input.keyCode <= 3) {
            this.p2PendingDir = input.keyCode;
          }
        }
        break;

      case MSG_TYPE.GAME_READY:
        if (this.isHost && !this.peerReady) {
          this.peerReady = true;
          this._startCountdown(0);
        }
        break;

      case MSG_TYPE.GAME_END: {
        const result = decodeGameEnd(buf);
        if (result) {
          this.gameState.phase = PHASE.MATCH_OVER;
          this.gameState.score1 = result.score1;
          this.gameState.score2 = result.score2;
          if (result.winner === 2) {
            // Peer is P2 — they won
            this.audio.playMatchWin();
          } else {
            this.audio.playMatchLose();
          }
        }
        break;
      }
    }
  }

  /** Peer: apply state from host, reconstruct grid on phase transitions. */
  _applyPeerState(decoded) {
    const prevPhase = this.gameState.phase;

    // Grid reset on new round (entering COUNTDOWN from any other phase)
    if (decoded.phase === PHASE.COUNTDOWN && prevPhase !== PHASE.COUNTDOWN) {
      const fresh = createInitialState(decoded.round);
      fresh.score1 = decoded.score1;
      fresh.score2 = decoded.score2;
      fresh.phase = decoded.phase;
      fresh.countdown = decoded.countdown;
      this.gameState = fresh;
      this.audio.playCountdown();
      return;
    }

    // Play countdown audio on countdown number change
    if (decoded.phase === PHASE.COUNTDOWN && decoded.countdown !== this.gameState.countdown) {
      this.audio.playCountdown();
    }

    // Play crash audio on round over transition
    if (decoded.phase === PHASE.ROUND_OVER && prevPhase !== PHASE.ROUND_OVER) {
      this.audio.playCrash();
      // Detect who won for round audio
      const prevScore1 = this.gameState.score1;
      const prevScore2 = this.gameState.score2;
      if (decoded.score1 > prevScore1) {
        // P1 won — peer lost
        // No round win audio for peer when they lost
      } else if (decoded.score2 > prevScore2) {
        this.audio.playRoundWin();
      }
    }

    // Update head positions in grid during PLAYING
    if (decoded.phase === PHASE.PLAYING) {
      this.gameState.grid[decoded.p1y][decoded.p1x] = CELL.P1_TRAIL;
      this.gameState.grid[decoded.p2y][decoded.p2x] = CELL.P2_TRAIL;
    }

    // Apply scalar fields
    this.gameState.p1 = { x: decoded.p1x, y: decoded.p1y, dir: decoded.p1dir };
    this.gameState.p2 = { x: decoded.p2x, y: decoded.p2y, dir: decoded.p2dir };
    this.gameState.score1 = decoded.score1;
    this.gameState.score2 = decoded.score2;
    this.gameState.phase = decoded.phase;
    this.gameState.countdown = decoded.countdown;
    this.gameState.round = decoded.round;
  }

  /** Direction queuing (sticky — no keyUp needed). */
  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    if (this.isHost) {
      this.p1PendingDir = keyCode;
    } else {
      this._safeSend(encodePlayerInput(keyCode, true));
    }

    this.audio.playMove();
  }

  _handleKeyUp(e) {
    // Direction is sticky — no action needed on key up
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();
  }

  /** Map keyboard key to INPUT_KEY/DIR enum. */
  _mapKey(key) {
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.UP;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.DOWN;
    if (key === "ArrowLeft" || key === "a" || key === "A") return INPUT_KEY.LEFT;
    if (key === "ArrowRight" || key === "d" || key === "D") {
      return INPUT_KEY.RIGHT;
    }
    return null;
  }

  /** Window blur — no-op for surround (directions are sticky). */
  _handleBlur() {
    // Intentionally empty: direction persists, no stuck-key issue
  }

  /** Host: start countdown for a round. */
  _startCountdown(round) {
    this._stopTickLoop();
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }

    // Create fresh grid for the new round
    const fresh = createInitialState(round);
    fresh.score1 = this._savedScores.score1;
    fresh.score2 = this._savedScores.score2;
    fresh.phase = PHASE.COUNTDOWN;
    fresh.countdown = 3;
    this.gameState = fresh;

    // Reset pending directions to initial facing
    this.p1PendingDir = this.gameState.p1.dir;
    this.p2PendingDir = this.gameState.p2.dir;

    this._broadcastState();
    this.audio.playCountdown();

    let count = 3;
    const tick = () => {
      count--;
      if (count > 0) {
        this.gameState.countdown = count;
        this._broadcastState();
        this.audio.playCountdown();
        this.phaseTimer = setTimeout(tick, 1000);
      } else {
        this._startPlaying();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  /** Host: transition to PLAYING phase and start tick loop. */
  _startPlaying() {
    this.gameState.phase = PHASE.PLAYING;
    this.gameState.countdown = 0;
    this._broadcastState();
    this._startTickLoop();
  }

  /** Host: start the 10Hz physics tick loop. */
  _startTickLoop() {
    this._stopTickLoop();
    this.tickInterval = setInterval(() => {
      this._tickLoop();
    }, TICK_INTERVAL);
  }

  /** Host: stop the tick loop. */
  _stopTickLoop() {
    if (this.tickInterval) {
      clearInterval(this.tickInterval);
      this.tickInterval = null;
    }
  }

  /** Host: one physics tick — move players, check collisions, broadcast. */
  _tickLoop() {
    if (this.gameState.phase !== PHASE.PLAYING) return;

    const result = moveAndCheck(this.gameState, this.p1PendingDir, this.p2PendingDir);

    this.gameState = result;

    if (result.p1Dead || result.p2Dead) {
      this._handleRoundOver(result.p1Dead, result.p2Dead);
      return;
    }

    this._broadcastState();
  }

  /** Host: handle a player death (round over). */
  _handleRoundOver(p1Dead, p2Dead) {
    this._stopTickLoop();
    this.audio.playCrash();

    // Create crash particles
    if (p1Dead) {
      this.gameState.particles = [
        ...this.gameState.particles,
        ...createCrashParticles(this.gameState.p1.x, this.gameState.p1.y, gameColor("00ff41")),
      ];
    }
    if (p2Dead) {
      this.gameState.particles = [
        ...this.gameState.particles,
        ...createCrashParticles(this.gameState.p2.x, this.gameState.p2.y, gameColor("00d4ff")),
      ];
    }

    // Award points
    if (p1Dead && !p2Dead) {
      this.gameState.score2++;
    } else if (p2Dead && !p1Dead) {
      this.gameState.score1++;
    }
    // Both dead = draw, no points awarded

    // Save scores for next round
    this._savedScores.score1 = this.gameState.score1;
    this._savedScores.score2 = this.gameState.score2;

    // Check for match winner
    if (this.gameState.score1 >= WINS_NEEDED || this.gameState.score2 >= WINS_NEEDED) {
      this.gameState.phase = PHASE.MATCH_OVER;
      this._broadcastState();
      this._handleMatchOver();
      return;
    }

    // Round over with round win audio
    this.gameState.phase = PHASE.ROUND_OVER;
    if (!p1Dead && p2Dead) {
      this.audio.playRoundWin();
    }
    this._broadcastState();

    // Schedule next round
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
    }
    this.phaseTimer = setTimeout(() => {
      this.phaseTimer = null;
      this._startCountdown(this.gameState.round + 1);
    }, ROUND_OVER_DELAY);
  }

  /** Host: handle match end. */
  _handleMatchOver() {
    const { score1, score2 } = this.gameState;
    const winner = score1 >= WINS_NEEDED ? 1 : 2;

    if (winner === 1) {
      this.audio.playMatchWin();
    } else {
      this.audio.playMatchLose();
    }

    // Send game end to peer
    this._safeSend(encodeGameEnd(score1, score2, winner));

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: score1, p2: score2 },
        winner,
      });
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    if (!this.gameState || this.gameState.phase === PHASE.MATCH_OVER) return;
    this.gameState.phase = PHASE.MATCH_OVER;
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.score1, p2: this.gameState.score2 },
          winner: 0,
          disconnected: true,
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  /** Send game state over DataChannel. */
  _broadcastState() {
    this._safeSend(encodeGameState(this.gameState));
  }

  /** 60fps render loop (runs on both host and peer). */
  _renderLoop(timestamp) {
    if (!this.running) return;

    // Update particles
    if (this.gameState.particles && this.gameState.particles.length > 0) {
      this.gameState.particles = updateParticles(this.gameState.particles);
    }

    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, timestamp);
    }

    this.animFrame = requestAnimationFrame(this._boundRenderLoop);
  }
}
