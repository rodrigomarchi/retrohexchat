/**
 * OutlawEngine — extends GameEngine with western duel game loop.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/hex_outlaw_engine
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  INPUT_KEY,
  GAME_MODE,
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
  moveGunslinger,
  fireBullet,
  tickBullets,
  checkBulletCollisions,
  tickObstacle,
  enterHitPause,
  tickHitPause,
  checkRoundEnd,
  advanceRound,
  resetForNewRound,
  BULLET_SPEED_X,
} from "./physics.js";
import {
  render as renderFrame,
  getColors,
  createHitParticles,
  updateParticles,
} from "./renderer.js";
import { OutlawAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Send state every N frames (~30Hz at 60fps)
const ROUND_OVER_DELAY = 2500; // ms display round over screen
const SPAWNING_DELAY = 1000; // ms "DRAW!" display

/**
 * Map game_id to GAME_MODE enum value.
 * Default is QUICK_DRAW.
 * @param {string} gameId
 * @returns {number}
 */
function gameModeFromId(gameId) {
  switch (gameId) {
    case "hex_outlaw_ricochet":
      return GAME_MODE.RICOCHET;
    case "hex_outlaw_stagecoach":
      return GAME_MODE.STAGECOACH;
    case "hex_outlaw_nml":
      return GAME_MODE.NO_MANS_LAND;
    default:
      return GAME_MODE.QUICK_DRAW;
  }
}

export class OutlawEngine extends GameEngine {
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

    const mode = gameModeFromId(gameId);
    this.gameState = createInitialState(mode);
    this.particles = [];

    this.remoteInputs = {
      up: false,
      down: false,
      left: false,
      right: false,
      fire: false,
    };
    this.localInputs = {
      up: false,
      down: false,
      left: false,
      right: false,
      fire: false,
    };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new OutlawAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);

    // Edge-trigger fire (only fire on press, not hold)
    this._localFirePressed = false;
    this._remoteFirePressed = false;

    // Track last aim direction for ricochet (up or down)
    this._localAimUp = false;
    this._remoteAimUp = false;
  }

  start() {
    if (this.running) return;
    super.start();
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.isHost) {
      this._renderState();
    } else {
      this._safeSend(encodeGameReady());
      this._renderState();
    }
  }

  stop() {
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }
    if (this.animFrame) {
      cancelAnimationFrame(this.animFrame);
      this.animFrame = null;
    }
    this.running = false;
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    this.audio.dispose();
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
          const decoded = decodeGameState(buf, BULLET_SPEED_X);
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
    if (input.keyCode === INPUT_KEY.UP) {
      this.remoteInputs.up = input.pressed;
    } else if (input.keyCode === INPUT_KEY.DOWN) {
      this.remoteInputs.down = input.pressed;
    } else if (input.keyCode === INPUT_KEY.LEFT) {
      this.remoteInputs.left = input.pressed;
    } else if (input.keyCode === INPUT_KEY.RIGHT) {
      this.remoteInputs.right = input.pressed;
    } else if (input.keyCode === INPUT_KEY.FIRE) {
      this.remoteInputs.fire = input.pressed;
    }
  }

  _applyPeerState(decoded) {
    const prevPhase = this.gameState.phase;
    const prevB1Active = this.gameState.b1active;
    const prevB2Active = this.gameState.b2active;

    // Apply all decoded fields
    Object.assign(this.gameState, decoded);

    // Peer audio: gunshot when bullet becomes active
    if (!prevB1Active && decoded.b1active) this.audio.playGunshot();
    if (!prevB2Active && decoded.b2active) this.audio.playGunshot();

    // Peer audio: hit
    if (decoded.lastHitPlayer !== 0) {
      this.audio.playHit();
      const defPrefix = decoded.lastHitPlayer === 1 ? "p2" : "p1";
      this.particles = [
        ...this.particles,
        ...createHitParticles(decoded[`${defPrefix}x`], decoded[`${defPrefix}y`]),
      ];
    }

    this._playPhaseAudio(prevPhase, decoded.phase);
  }

  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    this._setLocalInput(keyCode, true);

    // Track aim direction for ricochet: last vertical input determines angle
    if (keyCode === INPUT_KEY.UP) this._localAimUp = true;
    if (keyCode === INPUT_KEY.DOWN) this._localAimUp = false;

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
    else if (keyCode === INPUT_KEY.FIRE) this.localInputs.fire = pressed;
  }

  _mapKey(key) {
    if (key === "ArrowUp" || key === "w" || key === "W") {
      return INPUT_KEY.UP;
    }
    if (key === "ArrowDown" || key === "s" || key === "S") {
      return INPUT_KEY.DOWN;
    }
    if (key === "ArrowLeft" || key === "a" || key === "A") {
      return INPUT_KEY.LEFT;
    }
    if (key === "ArrowRight" || key === "d" || key === "D") {
      return INPUT_KEY.RIGHT;
    }
    if (key === " " || key === "Shift") {
      return INPUT_KEY.FIRE;
    }
    return null;
  }

  _handleBlur() {
    this.localInputs = {
      up: false,
      down: false,
      left: false,
      right: false,
      fire: false,
    };
    this._localFirePressed = false;
    this._remoteFirePressed = false;

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.UP, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.DOWN, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.LEFT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.RIGHT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.FIRE, false));
    }
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
    this.audio.playBell();

    this.phaseTimer = setTimeout(() => {
      if (!this.running) return;
      this.gameState.phase = PHASE.PLAYING;
      this._broadcastState();
      this._startGameLoop();
    }, SPAWNING_DELAY);
  }

  _startGameLoop() {
    if (this.animFrame) cancelAnimationFrame(this.animFrame);
    this.frameCount = 0;
    // Reset fire state to prevent pre-loaded shots from countdown
    this._localFirePressed = this.localInputs.fire;
    this._remoteFirePressed = this.remoteInputs.fire;
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
    s = { ...s, lastHitPlayer: 0 };

    // Handle hit pause
    if (s.phase === PHASE.HIT_PAUSE) {
      s = tickHitPause(s);
      // Also tick obstacle during pause (stagecoach keeps moving)
      s = tickObstacle(s);
      this.gameState = s;
      this.particles = updateParticles(this.particles);
      this._renderState();
      this.frameCount++;
      if (this.frameCount % STATE_SEND_INTERVAL === 0) {
        this._broadcastState();
      }
      this.animFrame = requestAnimationFrame(this._boundGameLoop);
      return;
    }

    // P1 movement (host = P1)
    const p1dy = (this.localInputs.down ? 1 : 0) - (this.localInputs.up ? 1 : 0);
    const p1dx = (this.localInputs.right ? 1 : 0) - (this.localInputs.left ? 1 : 0);
    if (p1dy !== 0 || p1dx !== 0) {
      s = moveGunslinger(s, 1, p1dy, p1dx);
    }

    // P2 movement (remote = P2)
    const p2dy = (this.remoteInputs.down ? 1 : 0) - (this.remoteInputs.up ? 1 : 0);
    const p2dx = (this.remoteInputs.right ? 1 : 0) - (this.remoteInputs.left ? 1 : 0);
    if (p2dy !== 0 || p2dx !== 0) {
      s = moveGunslinger(s, 2, p2dy, p2dx);
    }

    // Edge-triggered fire
    if (this.localInputs.fire && !this._localFirePressed) {
      const prev = s;
      s = fireBullet(s, 1, this._localAimUp);
      if (s !== prev) this.audio.playGunshot();
    }
    this._localFirePressed = this.localInputs.fire;

    if (this.remoteInputs.fire && !this._remoteFirePressed) {
      const prev = s;
      s = fireBullet(s, 2, this._remoteAimUp);
      if (s !== prev) this.audio.playGunshot();
    }
    this._remoteFirePressed = this.remoteInputs.fire;

    // Track remote aim direction
    if (this.remoteInputs.up) this._remoteAimUp = true;
    if (this.remoteInputs.down) this._remoteAimUp = false;

    // Tick obstacle (stagecoach movement)
    s = tickObstacle(s);

    // Tick bullets (movement + ricochet)
    const prevB1Bounced = s.b1bounced;
    const prevB2Bounced = s.b2bounced;
    s = tickBullets(s);

    // Ricochet audio
    if (!prevB1Bounced && s.b1bounced) this.audio.playRicochet();
    if (!prevB2Bounced && s.b2bounced) this.audio.playRicochet();

    // Check bullet collisions
    const { state: collState, p1Hit, p2Hit, obsHit } = checkBulletCollisions(s);
    s = collState;

    // Collision audio + particles
    if (p1Hit || p2Hit) {
      this.audio.playHit();
      const hitPrefix = p2Hit ? "p2" : "p1";
      this.particles = [
        ...this.particles,
        ...createHitParticles(s[`${hitPrefix}x`], s[`${hitPrefix}y`]),
      ];
    }
    if (obsHit) {
      this.audio.playObstacleHit();
    }

    // Check scoring → enter hit pause or round end
    if (p1Hit || p2Hit) {
      const { ended, roundWinner } = checkRoundEnd(s);
      if (ended) {
        s = advanceRound(s, roundWinner);

        if (s.phase === PHASE.MATCH_OVER) {
          this.gameState = s;
          this._handleMatchOver();
          return;
        }

        // Round over
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

      // Enter hit pause (positions reset after pause)
      s = enterHitPause(s);
      // Force immediate broadcast so peer sees hit event + phase change
      this.gameState = s;
      this._broadcastState();
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

  // ── Connection Resilience ──

  _handleChannelClose() {
    if (!this.gameState || this.gameState.phase === PHASE.MATCH_OVER) return;
    this.gameState.phase = PHASE.MATCH_OVER;
    this._renderState();
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
      } catch {
        // callback error — ignore
      }
    }
  }

  _broadcastState() {
    this._safeSend(encodeGameState(this.gameState, BULLET_SPEED_X));
  }

  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, this.frameCount, this.particles);
    }
  }

  _playPhaseAudio(prevPhase, newPhase) {
    if (prevPhase === newPhase) return;
    if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
    if (newPhase === PHASE.SPAWNING) this.audio.playBell();
  }
}
