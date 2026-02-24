/**
 * BoxingEngine — extends GameEngine with top-down boxing game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/hex_boxing_engine
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
  moveBoxer,
  startPunch,
  tickPunchTimers,
  checkPunchHit,
  tickRoundTimer,
  checkRoundEnd,
  advanceRound,
  resetForNewRound,
  ROUND_DURATION,
} from "./physics.js";
import {
  render as renderFrame,
  getColors,
  createHitParticles,
  updateParticles,
} from "./renderer.js";
import { BoxingAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Send state every N frames (~30Hz at 60fps)
const ROUND_OVER_DELAY = 2500; // ms display round over screen
const SPAWNING_DELAY = 1000; // ms "FIGHT!" display

export class BoxingEngine extends GameEngine {
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
    this.particles = [];

    this.remoteInputs = {
      up: false,
      down: false,
      left: false,
      right: false,
      punch: false,
    };
    this.localInputs = {
      up: false,
      down: false,
      left: false,
      right: false,
      punch: false,
    };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new BoxingAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);

    // Edge-trigger punch (only punch on press, not hold)
    this._localPunchPressed = false;
    this._remotePunchPressed = false;
  }

  start() {
    super.start();
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
    this._localPunchPressed = false;
    this._remotePunchPressed = false;
    this.channel.removeEventListener("message", this._boundOnMessage);
    document.removeEventListener("keydown", this._boundOnKeyDown);
    document.removeEventListener("keyup", this._boundOnKeyUp);
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
            this._renderState();
          }
        }
        break;

      case MSG_TYPE.PLAYER_INPUT:
        if (this.isHost) {
          const input = decodePlayerInput(buf);
          if (input) {
            this._applyRemoteInput(input);
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
          this.gameState.phase = PHASE.MATCH_OVER;
          this.gameState.roundWins1 = result.roundWins1;
          this.gameState.roundWins2 = result.roundWins2;
          // Peer is P2 — determine if they won
          if (result.winner === 2) {
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

  _applyRemoteInput(input) {
    if (input.keyCode === INPUT_KEY.UP) this.remoteInputs.up = input.pressed;
    else if (input.keyCode === INPUT_KEY.DOWN) this.remoteInputs.down = input.pressed;
    else if (input.keyCode === INPUT_KEY.LEFT) this.remoteInputs.left = input.pressed;
    else if (input.keyCode === INPUT_KEY.RIGHT) this.remoteInputs.right = input.pressed;
    else if (input.keyCode === INPUT_KEY.PUNCH) this.remoteInputs.punch = input.pressed;
  }

  _applyPeerState(decoded) {
    const prevPhase = this.gameState.phase;

    // Apply all decoded fields
    this.gameState.b1x = decoded.b1x;
    this.gameState.b1y = decoded.b1y;
    this.gameState.b1dir = decoded.b1dir;
    this.gameState.b1punchState = decoded.b1punchState;
    this.gameState.b1arm = decoded.b1arm;
    this.gameState.b1punchTimer = decoded.b1punchTimer;
    this.gameState.b2x = decoded.b2x;
    this.gameState.b2y = decoded.b2y;
    this.gameState.b2dir = decoded.b2dir;
    this.gameState.b2punchState = decoded.b2punchState;
    this.gameState.b2arm = decoded.b2arm;
    this.gameState.b2punchTimer = decoded.b2punchTimer;
    this.gameState.score1 = decoded.score1;
    this.gameState.score2 = decoded.score2;
    this.gameState.phase = decoded.phase;
    this.gameState.countdown = decoded.countdown;
    this.gameState.round = decoded.round;
    this.gameState.roundWins1 = decoded.roundWins1;
    this.gameState.roundWins2 = decoded.roundWins2;
    this.gameState.roundTimer = decoded.roundTimer;
    this.gameState.lastHitPlayer = decoded.lastHitPlayer;
    this.gameState.lastHitPoints = decoded.lastHitPoints;

    // Peer audio: play hit sound when events arrive
    if (decoded.lastHitPlayer !== 0 && decoded.lastHitPoints > 0) {
      this.audio.playHit(decoded.lastHitPoints);
      // Create particles at the defender's position
      const defPrefix = decoded.lastHitPlayer === 1 ? "b2" : "b1";
      this.particles = [
        ...this.particles,
        ...createHitParticles(
          decoded[`${defPrefix}x`],
          decoded[`${defPrefix}y`],
          decoded.lastHitPoints,
        ),
      ];
    }

    this._playPhaseAudio(prevPhase, decoded.phase);
  }

  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    this._setLocalInput(keyCode, true);

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(keyCode, true));
    }
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    this._setLocalInput(keyCode, false);

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(keyCode, false));
    }
  }

  _setLocalInput(keyCode, pressed) {
    if (keyCode === INPUT_KEY.UP) this.localInputs.up = pressed;
    else if (keyCode === INPUT_KEY.DOWN) this.localInputs.down = pressed;
    else if (keyCode === INPUT_KEY.LEFT) this.localInputs.left = pressed;
    else if (keyCode === INPUT_KEY.RIGHT) this.localInputs.right = pressed;
    else if (keyCode === INPUT_KEY.PUNCH) this.localInputs.punch = pressed;
  }

  _mapKey(key) {
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.UP;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.DOWN;
    if (key === "ArrowLeft" || key === "a" || key === "A") return INPUT_KEY.LEFT;
    if (key === "ArrowRight" || key === "d" || key === "D") return INPUT_KEY.RIGHT;
    if (key === " " || key === "Shift") return INPUT_KEY.PUNCH;
    return null;
  }

  _handleBlur() {
    this.localInputs = { up: false, down: false, left: false, right: false, punch: false };

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.UP, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.DOWN, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.LEFT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.RIGHT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.PUNCH, false));
    }
  }

  // --- Direction from input state ---

  /**
   * Compute 8-direction index from input booleans.
   * Returns -1 if no direction pressed.
   * @param {object} inputs
   * @returns {number}
   */
  _dirFromInputs(inputs) {
    const { up, down, left, right } = inputs;
    if (right && !left) {
      if (up && !down) return 7; // up-right
      if (down && !up) return 1; // down-right
      return 0; // right
    }
    if (left && !right) {
      if (up && !down) return 5; // up-left
      if (down && !up) return 3; // down-left
      return 4; // left
    }
    if (up && !down) return 6; // up
    if (down && !up) return 2; // down
    return -1; // no direction
  }

  // --- Phase management (host only) ---

  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._renderState();
    this.audio.playCountdown();

    let count = 3;
    const tick = () => {
      if (!this.running) return;
      count--;
      if (count > 0) {
        this.gameState.countdown = count;
        this._broadcastState();
        this._renderState();
        this.audio.playCountdown();
        this.phaseTimer = setTimeout(tick, 1000);
      } else {
        this._startSpawning();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  _startSpawning() {
    this.gameState.phase = PHASE.SPAWNING;
    this._broadcastState();
    this._renderState();
    this.audio.playBellStart();

    this.phaseTimer = setTimeout(() => {
      if (!this.running) return;
      this.gameState.phase = PHASE.FIGHTING;
      this.gameState.roundTimer = ROUND_DURATION;
      this._broadcastState();
      this._startGameLoop();
    }, SPAWNING_DELAY);
  }

  _startGameLoop() {
    if (this.animFrame) cancelAnimationFrame(this.animFrame);
    this.frameCount = 0;
    this._localPunchPressed = false;
    this._remotePunchPressed = false;
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  _renderDuringPause() {
    if (!this.running) return;
    this.particles = updateParticles(this.particles);
    this._renderState();
    if (this.particles.length > 0) {
      this.animFrame = requestAnimationFrame(() => this._renderDuringPause());
    }
  }

  _gameLoop(_timestamp) {
    if (!this.running) return;

    let s = this.gameState;

    // Clear event flags
    s = { ...s, lastHitPlayer: 0, lastHitPoints: 0 };

    // P1 inputs (host = P1)
    const p1Dir = this._dirFromInputs(this.localInputs);
    if (p1Dir >= 0) {
      s = moveBoxer(s, 1, p1Dir);
    }

    // P2 inputs (remote = P2)
    const p2Dir = this._dirFromInputs(this.remoteInputs);
    if (p2Dir >= 0) {
      s = moveBoxer(s, 2, p2Dir);
    }

    // Edge-triggered punch (only on press, not hold)
    if (this.localInputs.punch && !this._localPunchPressed) {
      s = startPunch(s, 1);
    }
    this._localPunchPressed = this.localInputs.punch;

    if (this.remoteInputs.punch && !this._remotePunchPressed) {
      s = startPunch(s, 2);
    }
    this._remotePunchPressed = this.remoteInputs.punch;

    // Tick punch timers
    s = tickPunchTimers(s);

    // Check hits (both boxers can hit simultaneously)
    const prevScore1 = s.score1;
    s = checkPunchHit(s, 1); // P1 hits P2
    const p1Hit = s.score1 > prevScore1;
    const p1HitPoints = p1Hit ? s.lastHitPoints : 0;

    const prevScore2 = s.score2;
    s = checkPunchHit(s, 2); // P2 hits P1
    const p2Hit = s.score2 > prevScore2;
    const p2HitPoints = p2Hit ? s.lastHitPoints : 0;

    // Audio + particles for hits
    if (p1Hit) {
      this.audio.playHit(p1HitPoints);
      this.particles = [...this.particles, ...createHitParticles(s.b2x, s.b2y, p1HitPoints)];
    }
    if (p2Hit) {
      this.audio.playHit(p2HitPoints);
      this.particles = [...this.particles, ...createHitParticles(s.b1x, s.b1y, p2HitPoints)];
    }

    // Tick round timer
    s = tickRoundTimer(s);

    // Timer tick audio (last 15 seconds = 900 frames)
    if (s.roundTimer <= 900 && s.roundTimer > 0 && s.roundTimer % 60 === 0) {
      this.audio.playTimerTick();
    }

    // Check round end
    const { ended, roundWinner } = checkRoundEnd(s);
    if (ended) {
      s = advanceRound(s, roundWinner);

      if (s.koPlayer > 0) {
        this.audio.playKO();
      } else {
        this.audio.playBellEnd();
      }

      if (s.phase === PHASE.MATCH_OVER) {
        this.gameState = s;
        this._handleMatchOver();
        return;
      }

      // Round over — keep rendering particles, then start next round
      this.gameState = s;
      this._broadcastState();
      this._renderDuringPause();

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
    this._renderState();

    // Broadcast
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  _handleMatchOver() {
    const winner = this.gameState.roundWins1 >= this.gameState.roundWins2 ? 1 : 2;

    if (winner === 1) {
      this.audio.playWin();
    } else {
      this.audio.playLose();
    }

    // Send GAME_END to peer
    this._safeSend(
      encodeGameEnd({
        score1: this.gameState.score1,
        score2: this.gameState.score2,
        winner,
        roundWins1: this.gameState.roundWins1,
        roundWins2: this.gameState.roundWins2,
      }),
    );
    this._broadcastState();
    this._renderState();

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

  _broadcastState() {
    this._safeSend(encodeGameState(this.gameState));
  }

  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, this.frameCount, this.particles);
    }
  }

  _playPhaseAudio(prevPhase, newPhase) {
    if (prevPhase === newPhase) return;
    if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
    if (newPhase === PHASE.SPAWNING) this.audio.playBellStart();
    if (newPhase === PHASE.ROUND_OVER) this.audio.playBellEnd();
  }
}
