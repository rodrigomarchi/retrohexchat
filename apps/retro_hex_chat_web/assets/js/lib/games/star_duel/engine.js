/**
 * StarDuelEngine — extends GameEngine with Star Duel space combat game loop.
 * Host-authoritative: creator runs 60fps physics, peer receives state snapshots.
 * Supports 3 game modes: Open Space, Gravity Well, Debris Field.
 * @module games/star_duel_engine
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
  encodeShipFlags,
  getMessageType,
} from "./protocol.js";
import {
  createInitialState,
  updateShipRotation,
  applyThrust,
  applyDrag,
  capSpeed,
  updateShipPosition,
  fireMissile,
  updateMissiles,
  tickCooldowns,
  checkMissileShipCollision,
  checkShipShipCollision,
  attemptWarp,
  spawnShips,
  applyGravity,
  applyGravityToMissile,
  checkStarCollision,
  checkAsteroidShipCollision,
  checkAsteroidMissileCollision,
  generateAsteroids,
  createExplosionParticles,
  updateParticles,
  STAR_X,
  STAR_Y,
  WIN_SCORE,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { StarDuelAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Send every 2 frames (~30Hz)
const SPAWN_DELAY = 1500; // ms pause after round over
const ROUND_OVER_DELAY = 2000; // ms before respawn

const MODE_MAP = { star_duel: 0, gravity_well: 1, debris_field: 2 };

export class StarDuelEngine extends GameEngine {
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
    this.mode = MODE_MAP[gameId] ?? 0;
    this.gameState = createInitialState(this.mode);
    this.gameState.lastScorer = 0;
    this.remoteInputs = {
      rotateLeft: false,
      rotateRight: false,
      thrust: false,
      fire: false,
      warp: false,
    };
    this.localInputs = {
      rotateLeft: false,
      rotateRight: false,
      thrust: false,
      fire: false,
      warp: false,
    };
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new StarDuelAudio();
    this.colors = null;
    this.peerReady = false;

    // Edge-trigger tracking for fire and warp (only activate once per keydown)
    this._p1FirePrev = false;
    this._p2FirePrev = false;
    this._p1WarpPrev = false;
    this._p2WarpPrev = false;

    // Thrust audio state tracking
    this._thrustAudioPlaying = false;
    this._peerThrustAudioPlaying = false;

    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.isHost) {
      // Host waits for peer GAME_READY, then starts countdown
      this._renderState();
    } else {
      // Peer sends ready signal
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
    this.audio.stopThrust();
    this.audio.stopStarProximity();
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
          this.gameState.phase = PHASE.FINISHED;
          this.gameState.winner = result.winner;
          this.gameState.score1 = result.score1;
          this.gameState.score2 = result.score2;
          this.audio.playWin();
          this.audio.stopThrust();
          this.audio.stopStarProximity();
          this._peerThrustAudioPlaying = false;
          this._renderState();
        }
        break;
      }
    }
  }

  /**
   * Apply a remote player input message to remoteInputs (host only).
   * Fire and warp are edge-triggered: peer sends pressed=true once on keydown,
   * and pressed=false on keyup. The host detects false->true transitions.
   * @param {{keyCode: number, pressed: boolean}} input
   */
  _applyRemoteInput(input) {
    switch (input.keyCode) {
      case INPUT_KEY.ROTATE_LEFT:
        this.remoteInputs.rotateLeft = input.pressed;
        break;
      case INPUT_KEY.ROTATE_RIGHT:
        this.remoteInputs.rotateRight = input.pressed;
        break;
      case INPUT_KEY.THRUST:
        this.remoteInputs.thrust = input.pressed;
        break;
      case INPUT_KEY.FIRE:
        this.remoteInputs.fire = input.pressed;
        break;
      case INPUT_KEY.WARP:
        this.remoteInputs.warp = input.pressed;
        break;
    }
  }

  _handleKeyDown(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;
    e.preventDefault();

    if (this.isHost) {
      if (keyCode === INPUT_KEY.ROTATE_LEFT) this.localInputs.rotateLeft = true;
      if (keyCode === INPUT_KEY.ROTATE_RIGHT) this.localInputs.rotateRight = true;
      if (keyCode === INPUT_KEY.THRUST) this.localInputs.thrust = true;
      if (keyCode === INPUT_KEY.FIRE) this.localInputs.fire = true;
      if (keyCode === INPUT_KEY.WARP) this.localInputs.warp = true;
    } else {
      this._safeSend(encodePlayerInput(keyCode, true));
    }
  }

  _handleKeyUp(e) {
    const keyCode = this._mapKey(e.key);
    if (keyCode === null) return;

    if (this.isHost) {
      if (keyCode === INPUT_KEY.ROTATE_LEFT) this.localInputs.rotateLeft = false;
      if (keyCode === INPUT_KEY.ROTATE_RIGHT) this.localInputs.rotateRight = false;
      if (keyCode === INPUT_KEY.THRUST) this.localInputs.thrust = false;
      if (keyCode === INPUT_KEY.FIRE) this.localInputs.fire = false;
      if (keyCode === INPUT_KEY.WARP) this.localInputs.warp = false;
    } else {
      this._safeSend(encodePlayerInput(keyCode, false));
    }
  }

  /** Map keyboard key to INPUT_KEY enum. */
  _mapKey(key) {
    if (key === "ArrowLeft" || key === "a" || key === "A") return INPUT_KEY.ROTATE_LEFT;
    if (key === "ArrowRight" || key === "d" || key === "D") return INPUT_KEY.ROTATE_RIGHT;
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.THRUST;
    if (key === " ") return INPUT_KEY.FIRE;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.WARP;
    return null;
  }

  /** Clear all inputs on window blur (prevents stuck keys). */
  _handleBlur() {
    this.localInputs = {
      rotateLeft: false,
      rotateRight: false,
      thrust: false,
      fire: false,
      warp: false,
    };
    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.ROTATE_LEFT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.ROTATE_RIGHT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.THRUST, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.FIRE, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.WARP, false));
    }
    this.audio.stopThrust();
    this._thrustAudioPlaying = false;
  }

  /** Host: start countdown phase. */
  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._renderState();
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
        this.phaseTimer = null;
        this._startSpawning();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  /** Host: transition to spawning phase. */
  _startSpawning() {
    this.gameState.phase = PHASE.SPAWNING;
    this._broadcastState();
    this._renderState();
    this.audio.playSpawn();

    this.phaseTimer = setTimeout(() => {
      this.phaseTimer = null;
      this._startGameLoop();
    }, SPAWN_DELAY);
  }

  /** Host: start the main game loop. */
  _startGameLoop() {
    this.gameState.phase = PHASE.PLAYING;
    this.gameState = spawnShips(this.gameState);
    this.frameCount = 0;

    // Reset edge-trigger flags
    this._p1FirePrev = false;
    this._p2FirePrev = false;
    this._p1WarpPrev = false;
    this._p2WarpPrev = false;

    this._broadcastState();
    this._renderState();
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  /** Host: main game loop (60Hz via requestAnimationFrame). */
  _gameLoop(_timestamp) {
    if (!this.running) return;

    const state = this.gameState;

    // --- Process inputs for P1 (host/local) ---
    let ship1 = state.ship1;
    if (ship1.alive) {
      ship1 = updateShipRotation(ship1, this.localInputs.rotateLeft, this.localInputs.rotateRight);
      ship1 = { ...ship1, thrustActive: this.localInputs.thrust };
      ship1 = applyThrust(ship1);
      ship1 = applyDrag(ship1);
      ship1 = capSpeed(ship1);
      ship1 = updateShipPosition(ship1);
    }

    // --- Process inputs for P2 (remote) ---
    let ship2 = state.ship2;
    if (ship2.alive) {
      ship2 = updateShipRotation(
        ship2,
        this.remoteInputs.rotateLeft,
        this.remoteInputs.rotateRight,
      );
      ship2 = { ...ship2, thrustActive: this.remoteInputs.thrust };
      ship2 = applyThrust(ship2);
      ship2 = applyDrag(ship2);
      ship2 = capSpeed(ship2);
      ship2 = updateShipPosition(ship2);
    }

    // --- Fire missiles (edge-triggered) ---
    let { missiles } = state;

    // P1 fire: detect false->true edge
    const p1FireNow = this.localInputs.fire;
    if (p1FireNow && !this._p1FirePrev && ship1.alive) {
      const result = fireMissile(ship1, 1, missiles);
      if (result) {
        ship1 = result.ship;
        missiles = [...missiles, result.missile];
        this.audio.playFire();
      }
    }
    this._p1FirePrev = p1FireNow;

    // P2 fire: detect false->true edge
    const p2FireNow = this.remoteInputs.fire;
    if (p2FireNow && !this._p2FirePrev && ship2.alive) {
      const result = fireMissile(ship2, 2, missiles);
      if (result) {
        ship2 = result.ship;
        missiles = [...missiles, result.missile];
        this.audio.playFire();
      }
    }
    this._p2FirePrev = p2FireNow;

    // --- Warp (edge-triggered) ---
    // attemptWarp now checks alive/exploding and sets alive/exploding on death
    const p1WarpNow = this.localInputs.warp;
    if (p1WarpNow && !this._p1WarpPrev) {
      const warpResult = attemptWarp(ship1, Math.random);
      if (warpResult) {
        ship1 = warpResult.ship;
        this.audio.playWarp();
      }
    }
    this._p1WarpPrev = p1WarpNow;

    const p2WarpNow = this.remoteInputs.warp;
    if (p2WarpNow && !this._p2WarpPrev) {
      const warpResult = attemptWarp(ship2, Math.random);
      if (warpResult) {
        ship2 = warpResult.ship;
        this.audio.playWarp();
      }
    }
    this._p2WarpPrev = p2WarpNow;

    // --- Update missiles ---
    missiles = updateMissiles(missiles);

    // --- Mode-specific physics ---
    if (state.mode === GAME_MODE.GRAVITY_WELL) {
      // Apply gravity to ships (check star collision AFTER gravity)
      if (ship1.alive) {
        ship1 = applyGravity(ship1, STAR_X, STAR_Y);
        ship1 = capSpeed(ship1);
        if (checkStarCollision(ship1)) {
          ship1 = { ...ship1, alive: false, exploding: true };
        }
      }
      if (ship2.alive) {
        ship2 = applyGravity(ship2, STAR_X, STAR_Y);
        ship2 = capSpeed(ship2);
        if (checkStarCollision(ship2)) {
          ship2 = { ...ship2, alive: false, exploding: true };
        }
      }

      // Apply gravity to missiles
      missiles = missiles.map((m) => applyGravityToMissile(m, STAR_X, STAR_Y));

      // Star proximity audio — use closest ship distance
      const dx1 = ship1.x - STAR_X;
      const dy1 = ship1.y - STAR_Y;
      const dx2 = ship2.x - STAR_X;
      const dy2 = ship2.y - STAR_Y;
      const dist1 = Math.sqrt(dx1 * dx1 + dy1 * dy1);
      const dist2 = Math.sqrt(dx2 * dx2 + dy2 * dy2);
      this.audio.playStarProximity(Math.min(dist1, dist2));
    }

    if (state.mode === GAME_MODE.DEBRIS_FIELD) {
      if (ship1.alive && checkAsteroidShipCollision(ship1, state.asteroids)) {
        ship1 = { ...ship1, alive: false, exploding: true };
      }
      if (ship2.alive && checkAsteroidShipCollision(ship2, state.asteroids)) {
        ship2 = { ...ship2, alive: false, exploding: true };
      }
      missiles = checkAsteroidMissileCollision(missiles, state.asteroids);
    }

    // --- Collision checks ---
    const check1 = checkMissileShipCollision(missiles, ship1, 1);
    if (check1.hit) {
      ship1 = { ...ship1, alive: false, exploding: true };
      missiles = check1.missiles;
      this.audio.playHit();
    } else {
      missiles = check1.missiles;
    }

    const check2 = checkMissileShipCollision(missiles, ship2, 2);
    if (check2.hit) {
      ship2 = { ...ship2, alive: false, exploding: true };
      missiles = check2.missiles;
      this.audio.playHit();
    } else {
      missiles = check2.missiles;
    }

    if (checkShipShipCollision(ship1, ship2)) {
      ship1 = { ...ship1, alive: false, exploding: true };
      ship2 = { ...ship2, alive: false, exploding: true };
      this.audio.playHit();
    }

    // --- Tick cooldowns ---
    if (ship1.alive) ship1 = tickCooldowns(ship1);
    if (ship2.alive) ship2 = tickCooldowns(ship2);

    // --- Handle deaths ---
    let { particles } = state;
    let scoreChanged = false;
    let score1 = state.score1;
    let score2 = state.score2;
    let lastScorer = state.lastScorer || 0;

    const p1Died = ship1.exploding && ship1.alive === false && !state.ship1.exploding;
    const p2Died = ship2.exploding && ship2.alive === false && !state.ship2.exploding;

    if (p1Died && p2Died) {
      // Simultaneous death (ship-ship collision or mutual kill) — draw, no score
      particles = [...particles, ...createExplosionParticles(ship1.x, ship1.y)];
      particles = [...particles, ...createExplosionParticles(ship2.x, ship2.y)];
      this.audio.playDeath();
      scoreChanged = true;
      lastScorer = 0; // draw
    } else if (p1Died) {
      particles = [...particles, ...createExplosionParticles(ship1.x, ship1.y)];
      this.audio.playDeath();
      score2++;
      scoreChanged = true;
      lastScorer = 2;
    } else if (p2Died) {
      particles = [...particles, ...createExplosionParticles(ship2.x, ship2.y)];
      this.audio.playDeath();
      score1++;
      scoreChanged = true;
      lastScorer = 1;
    }

    // --- Update particles ---
    if (particles.length > 0) {
      particles = updateParticles(particles);
    }

    // --- Thrust audio management (host P1) ---
    if (ship1.thrustActive && ship1.alive && !this._thrustAudioPlaying) {
      this.audio.playThrust();
      this._thrustAudioPlaying = true;
    } else if ((!ship1.thrustActive || !ship1.alive) && this._thrustAudioPlaying) {
      this.audio.stopThrust();
      this._thrustAudioPlaying = false;
    }

    // --- Commit state ---
    this.gameState = {
      ...state,
      ship1,
      ship2,
      missiles,
      particles,
      score1,
      score2,
      lastScorer,
    };

    // --- Render ---
    this._renderState();

    // --- Broadcast state ---
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    // --- Phase transitions on score change ---
    if (scoreChanged) {
      if (score1 >= WIN_SCORE || score2 >= WIN_SCORE) {
        this._handleGameFinished();
        return;
      }
      this._handleRoundOver();
      return;
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  /** Host: handle round over (one ship died, but no winner yet). */
  _handleRoundOver() {
    this.gameState.phase = PHASE.ROUND_OVER;
    this._broadcastState();
    this._renderState();

    this.audio.stopThrust();
    this._thrustAudioPlaying = false;
    if (this.gameState.mode === GAME_MODE.GRAVITY_WELL) {
      this.audio.stopStarProximity();
    }

    this.phaseTimer = setTimeout(() => {
      this.phaseTimer = null;
      this._startSpawning();
    }, ROUND_OVER_DELAY);
  }

  /** Host: handle game end (a player reached WIN_SCORE). */
  _handleGameFinished() {
    const { score1, score2 } = this.gameState;
    const winner = score1 >= WIN_SCORE ? 1 : 2;

    this.gameState.phase = PHASE.FINISHED;
    this.gameState.winner = winner;
    this.audio.playWin();
    this.audio.stopThrust();
    this._thrustAudioPlaying = false;
    if (this.gameState.mode === GAME_MODE.GRAVITY_WELL) {
      this.audio.stopStarProximity();
    }

    // Send game end to peer
    this._safeSend(encodeGameEnd(score1, score2, winner));
    this._broadcastState();

    // Notify LiveView
    if (this.onGameEnd) {
      this.onGameEnd({
        score: { p1: score1, p2: score2 },
        winner,
      });
    }
  }

  /**
   * Prepare ship flags for protocol encoding.
   * The binary protocol expects a numeric flags byte on each ship.
   * @param {object} ship
   * @returns {object} ship with flags byte set
   */
  _prepareShipForEncoding(ship) {
    return {
      ...ship,
      flags: encodeShipFlags({
        alive: ship.alive,
        thrustActive: ship.thrustActive,
        exploding: ship.exploding,
        warping: ship.warping,
        invulnerable: ship.invulnerable,
      }),
    };
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    if (!this.gameState || this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this.audio.stopThrust();
    this.audio.stopStarProximity();
    this._renderState();
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

  /** Send game state over DataChannel with encoded ship flags. */
  _broadcastState() {
    const stateToSend = {
      ...this.gameState,
      ship1: this._prepareShipForEncoding(this.gameState.ship1),
      ship2: this._prepareShipForEncoding(this.gameState.ship2),
      invuln1: this.gameState.ship1.invulnTimer || 0,
      invuln2: this.gameState.ship2.invulnTimer || 0,
      warpCooldown1: this.gameState.ship1.warpCooldown || 0,
      warpCooldown2: this.gameState.ship2.warpCooldown || 0,
    };
    this._safeSend(encodeGameState(stateToSend));
  }

  /** Render current state to canvas. */
  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, performance.now());
    }
  }

  /**
   * Peer: apply decoded state from host, detect phase/event transitions for audio.
   * @param {object} decoded - decoded state from protocol
   */
  _applyPeerState(decoded) {
    const prevPhase = this.gameState.phase;
    const prevScore1 = this.gameState.score1;
    const prevScore2 = this.gameState.score2;
    const prevShip1Exploding = this.gameState.ship1.exploding;
    const prevShip2Exploding = this.gameState.ship2.exploding;

    // Reconstruct ships with boolean flags from decoded flag objects
    const ship1 = this._reconstructShip(decoded.ship1, decoded.invuln1, decoded.warpCooldown1);
    const ship2 = this._reconstructShip(decoded.ship2, decoded.invuln2, decoded.warpCooldown2);

    // Generate particles on peer when a ship transitions to exploding
    let particles = this.gameState.particles || [];
    if (ship1.exploding && !prevShip1Exploding) {
      particles = [...particles, ...createExplosionParticles(ship1.x, ship1.y)];
    }
    if (ship2.exploding && !prevShip2Exploding) {
      particles = [...particles, ...createExplosionParticles(ship2.x, ship2.y)];
    }

    this.gameState = {
      ...this.gameState,
      ship1,
      ship2,
      missiles: decoded.missiles,
      particles,
      score1: decoded.score1,
      score2: decoded.score2,
      phase: decoded.phase,
      countdown: decoded.countdown,
      mode: decoded.mode,
      asteroidSeed: decoded.asteroidSeed,
    };

    // Determine lastScorer for peer renderer
    if (decoded.score1 > prevScore1 && decoded.score2 === prevScore2) {
      this.gameState.lastScorer = 1;
    } else if (decoded.score2 > prevScore2 && decoded.score1 === prevScore1) {
      this.gameState.lastScorer = 2;
    } else if (decoded.score1 > prevScore1 && decoded.score2 > prevScore2) {
      this.gameState.lastScorer = 0; // draw
    }

    // Regenerate asteroids using host's seed (not random)
    if (
      decoded.mode === GAME_MODE.DEBRIS_FIELD &&
      decoded.asteroidSeed !== 0 &&
      this.gameState.asteroids.length === 0
    ) {
      this.gameState.asteroids = generateAsteroids(decoded.asteroidSeed);
    }

    // Peer thrust audio management
    if (ship2.thrustActive && ship2.alive && !this._peerThrustAudioPlaying) {
      this.audio.playThrust();
      this._peerThrustAudioPlaying = true;
    } else if ((!ship2.thrustActive || !ship2.alive) && this._peerThrustAudioPlaying) {
      this.audio.stopThrust();
      this._peerThrustAudioPlaying = false;
    }

    // Phase transition audio
    this._playPhaseAudio(prevPhase, decoded.phase, prevScore1, prevScore2);
  }

  /**
   * Reconstruct a full ship object from decoded protocol data.
   * The protocol decodes flags as an object {alive, thrustActive, exploding, warping, invulnerable}.
   * @param {object} decodedShip - ship from decodeGameState (has flags object)
   * @param {number} invulnTimer
   * @param {number} warpCooldown
   * @returns {object} full ship object
   */
  _reconstructShip(decodedShip, invulnTimer, warpCooldown) {
    return {
      x: decodedShip.x,
      y: decodedShip.y,
      vx: decodedShip.vx,
      vy: decodedShip.vy,
      rotation: decodedShip.rotation,
      alive: decodedShip.flags.alive,
      thrustActive: decodedShip.flags.thrustActive,
      exploding: decodedShip.flags.exploding,
      warping: decodedShip.flags.warping,
      invulnerable: decodedShip.flags.invulnerable,
      invulnTimer: invulnTimer || 0,
      fireCooldown: 0,
      warpCooldown: warpCooldown || 0,
    };
  }

  /**
   * Play audio based on phase transitions and score changes (peer side).
   * @param {number} prevPhase
   * @param {number} newPhase
   * @param {number} prevScore1
   * @param {number} prevScore2
   */
  _playPhaseAudio(prevPhase, newPhase, prevScore1, prevScore2) {
    if (prevPhase !== newPhase) {
      if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
      if (newPhase === PHASE.SPAWNING) this.audio.playSpawn();
      if (newPhase === PHASE.FINISHED) this.audio.playWin();
      if (newPhase === PHASE.ROUND_OVER || newPhase === PHASE.FINISHED) {
        this.audio.stopThrust();
        this._peerThrustAudioPlaying = false;
      }
    }
    if (this.gameState.score1 !== prevScore1 || this.gameState.score2 !== prevScore2) {
      this.audio.playDeath();
    }
  }
}
