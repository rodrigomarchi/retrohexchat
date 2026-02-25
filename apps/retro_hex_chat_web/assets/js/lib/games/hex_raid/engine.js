/**
 * HexRaidEngine — extends GameEngine with River Raid 2P game loop.
 * Host-authoritative: creator runs 60fps physics, peer receives state snapshots.
 * Supports 3 game modes: River Duel, Pacifist, Blitz.
 *
 * Architecture: continuous infinite scrolling — no discrete sections.
 * Entities spawn continuously as scrollY advances, drift downward in screen space.
 *
 * @module games/hex_raid_engine
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
  moveJet,
  accelerateJet,
  fireMissile,
  deployMine,
  updateScroll,
  updateEnemies,
  updateMissiles,
  updateMines,
  updateFuels,
  updateBridge,
  spawnEntities,
  drainFuel,
  checkRiverCollision,
  checkMissileHits,
  checkBridgeHits,
  checkEnemyCollisions,
  checkFuelCapture,
  checkMineCollisions,
  checkBridgeCollision,
  handleDeath,
  processRespawns,
  checkGameOver,
  getWinner,
  tickTimers,
  clearEvents,
  SCORE_FUEL_OUT,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { HexRaidAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Send state every N frames (~30Hz at 60fps)

/** Map gameId to GAME_MODE */
const MODE_MAP = {
  hex_raid: GAME_MODE.RIVER_DUEL,
  hex_raid_pacifist: GAME_MODE.PACIFIST,
  hex_raid_blitz: GAME_MODE.BLITZ,
};

export class HexRaidEngine extends GameEngine {
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

    this.mode = MODE_MAP[gameId] || GAME_MODE.RIVER_DUEL;
    this.seed = isHost ? ((Math.random() * 0xffffffff) | 0) >>> 0 : 0;
    this.gameState = createInitialState(this.mode, this.seed);
    this.particles = [];

    this.remoteInputs = {
      left: false,
      right: false,
      accel: false,
      decel: false,
      fire: false,
      mine: false,
    };
    this.localInputs = {
      left: false,
      right: false,
      accel: false,
      decel: false,
      fire: false,
      mine: false,
    };

    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new HexRaidAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);

    // Edge-trigger fire and mine (only on press, not hold)
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    this._localMinePressed = false;
    this._remoteMinePressed = false;
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
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    this._localMinePressed = false;
    this._remoteMinePressed = false;
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
          this.gameState.phase = PHASE.FINISHED;
          this.gameState.score1 = result.score1;
          this.gameState.score2 = result.score2;
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
    if (input.keyCode === INPUT_KEY.LEFT) this.remoteInputs.left = input.pressed;
    else if (input.keyCode === INPUT_KEY.RIGHT) this.remoteInputs.right = input.pressed;
    else if (input.keyCode === INPUT_KEY.ACCEL) this.remoteInputs.accel = input.pressed;
    else if (input.keyCode === INPUT_KEY.DECEL) this.remoteInputs.decel = input.pressed;
    else if (input.keyCode === INPUT_KEY.FIRE) this.remoteInputs.fire = input.pressed;
    else if (input.keyCode === INPUT_KEY.MINE) this.remoteInputs.mine = input.pressed;
  }

  _applyPeerState(decoded) {
    // Update seed if this is the first state (peer discovers seed here)
    if (this.seed === 0 && decoded.seed !== 0) {
      this.seed = decoded.seed;
      if (this.gameState.phase === PHASE.WAITING) {
        this.gameState = createInitialState(decoded.mode, decoded.seed);
      }
    }

    const prevPhase = this.gameState.phase;

    // Apply all decoded fields
    this.gameState.jet1X = decoded.jet1X;
    this.gameState.jet1Y = decoded.jet1Y;
    this.gameState.jet1Speed = decoded.jet1Speed;
    this.gameState.jet1Fuel = decoded.jet1Fuel;
    this.gameState.jet1Lives = decoded.jet1Lives;
    this.gameState.jet1Alive = decoded.jet1Alive;
    this.gameState.jet1Invuln = decoded.jet1Invuln;
    this.gameState.jet1Respawning = decoded.jet1Respawning;

    this.gameState.jet2X = decoded.jet2X;
    this.gameState.jet2Y = decoded.jet2Y;
    this.gameState.jet2Speed = decoded.jet2Speed;
    this.gameState.jet2Fuel = decoded.jet2Fuel;
    this.gameState.jet2Lives = decoded.jet2Lives;
    this.gameState.jet2Alive = decoded.jet2Alive;
    this.gameState.jet2Invuln = decoded.jet2Invuln;
    this.gameState.jet2Respawning = decoded.jet2Respawning;

    this.gameState.m1X = decoded.m1X;
    this.gameState.m1Y = decoded.m1Y;
    this.gameState.m1Active = decoded.m1Active;
    this.gameState.m2X = decoded.m2X;
    this.gameState.m2Y = decoded.m2Y;
    this.gameState.m2Active = decoded.m2Active;

    this.gameState.enemies = decoded.enemies;
    this.gameState.enemyCount = decoded.enemyCount;
    this.gameState.fuels = decoded.fuels;
    this.gameState.fuelCount = decoded.fuelCount;
    this.gameState.mines = decoded.mines;
    this.gameState.mineCount = decoded.mineCount;

    this.gameState.bridgeY = decoded.bridgeY;
    this.gameState.bridgeHp = decoded.bridgeHp;
    this.gameState.bridgeActive = decoded.bridgeActive;

    this.gameState.score1 = decoded.score1;
    this.gameState.score2 = decoded.score2;
    this.gameState.phase = decoded.phase;
    this.gameState.countdown = decoded.countdown;
    this.gameState.section = decoded.section;
    this.gameState.scrollY = decoded.scrollY;
    this.gameState.mode = decoded.mode;
    this.gameState.seed = decoded.seed;

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
    if (keyCode === INPUT_KEY.LEFT) this.localInputs.left = pressed;
    else if (keyCode === INPUT_KEY.RIGHT) this.localInputs.right = pressed;
    else if (keyCode === INPUT_KEY.ACCEL) this.localInputs.accel = pressed;
    else if (keyCode === INPUT_KEY.DECEL) this.localInputs.decel = pressed;
    else if (keyCode === INPUT_KEY.FIRE) this.localInputs.fire = pressed;
    else if (keyCode === INPUT_KEY.MINE) this.localInputs.mine = pressed;
  }

  _mapKey(key) {
    if (key === "ArrowLeft" || key === "a" || key === "A") return INPUT_KEY.LEFT;
    if (key === "ArrowRight" || key === "d" || key === "D") return INPUT_KEY.RIGHT;
    if (key === "ArrowUp" || key === "w" || key === "W") return INPUT_KEY.ACCEL;
    if (key === "ArrowDown" || key === "s" || key === "S") return INPUT_KEY.DECEL;
    if (key === " ") return INPUT_KEY.FIRE;
    if (key === "Shift" || key === "q" || key === "Q") return INPUT_KEY.MINE;
    return null;
  }

  _handleBlur() {
    this.localInputs = {
      left: false,
      right: false,
      accel: false,
      decel: false,
      fire: false,
      mine: false,
    };

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.LEFT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.RIGHT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.ACCEL, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.DECEL, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.FIRE, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.MINE, false));
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
        this._startFlying();
      }
    };
    this.phaseTimer = setTimeout(tick, 1000);
  }

  _startFlying() {
    this.gameState.phase = PHASE.FLYING;
    this._broadcastState();
    this._startGameLoop();
  }

  _startGameLoop() {
    if (this.animFrame) cancelAnimationFrame(this.animFrame);
    this.frameCount = 0;
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    this._localMinePressed = false;
    this._remoteMinePressed = false;
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  _gameLoop() {
    if (!this.running) return;

    let s = this.gameState;

    // Clear events
    s = clearEvents(s);

    // --- Apply inputs ---

    // P1 (host = P1)
    if (this.localInputs.left) s = moveJet(s, 1, -1);
    if (this.localInputs.right) s = moveJet(s, 1, 1);
    if (this.localInputs.accel) s = accelerateJet(s, 1, 1);
    if (this.localInputs.decel) s = accelerateJet(s, 1, -1);

    // P2 (remote = P2)
    if (this.remoteInputs.left) s = moveJet(s, 2, -1);
    if (this.remoteInputs.right) s = moveJet(s, 2, 1);
    if (this.remoteInputs.accel) s = accelerateJet(s, 2, 1);
    if (this.remoteInputs.decel) s = accelerateJet(s, 2, -1);

    // Fire missiles (edge-triggered)
    if (this.localInputs.fire && !this._localFirePressed) {
      const prev = s.m1Active;
      s = fireMissile(s, 1);
      if (s.m1Active && !prev) this.audio.playFire();
    }
    this._localFirePressed = this.localInputs.fire;

    if (this.remoteInputs.fire && !this._remoteFirePressed) {
      const prev = s.m2Active;
      s = fireMissile(s, 2);
      if (s.m2Active && !prev) this.audio.playFire();
    }
    this._remoteFirePressed = this.remoteInputs.fire;

    // Deploy mines (edge-triggered)
    if (this.localInputs.mine && !this._localMinePressed) {
      const prevCount = s.mineCount;
      s = deployMine(s, 1);
      if (s.mineCount > prevCount) this.audio.playMineDeploy();
    }
    this._localMinePressed = this.localInputs.mine;

    if (this.remoteInputs.mine && !this._remoteMinePressed) {
      const prevCount = s.mineCount;
      s = deployMine(s, 2);
      if (s.mineCount > prevCount) this.audio.playMineDeploy();
    }
    this._remoteMinePressed = this.remoteInputs.mine;

    // --- Update world ---
    const scrollResult = updateScroll(s);
    s = scrollResult.state;
    const scrollDelta = scrollResult.scrollDelta;

    // Spawn new entities ahead of camera
    s = spawnEntities(s);

    s = updateMissiles(s);
    s = updateEnemies(s, scrollDelta);
    s = updateFuels(s, scrollDelta);
    s = updateBridge(s, scrollDelta);
    s = updateMines(s, scrollDelta);
    s = drainFuel(s, this.frameCount);

    // --- Collisions ---
    s = checkMissileHits(s);
    s = checkBridgeHits(s);
    s = checkEnemyCollisions(s);
    s = checkFuelCapture(s);
    s = checkMineCollisions(s);
    s = checkBridgeCollision(s);

    // River collision check
    for (const player of [1, 2]) {
      if (checkRiverCollision(s, player)) {
        s = { ...s, events: { ...s.events, death: player } };
      }
    }

    // --- Handle events ---
    if (s.events.enemyKill) {
      this.audio.playEnemyDestroyed();
    }
    if (s.events.fuelCapture) {
      this.audio.playFuelCapture();
    }
    if (s.events.fuelDestroyed) {
      this.audio.playFuelDestroyed();
    }
    if (s.events.bridgeHit && !s.events.bridgeDestroyed) {
      this.audio.playBridgeHit();
    }
    if (s.events.bridgeDestroyed) {
      this.audio.playBridgeDestroyed();
    }
    if (s.events.mineHit) {
      this.audio.playMineHit();
    }

    // Handle death
    if (s.events.death) {
      this.audio.playDeath();
      s = handleDeath(s, s.events.death);

      // Fuel empty bonus for opponent
      if (s.events.fuelEmpty) {
        const bonusKey = s.events.fuelEmpty === 1 ? "score2" : "score1";
        s = { ...s, [bonusKey]: s[bonusKey] + SCORE_FUEL_OUT };
      }
    }

    // Respawns
    const prevJ1Alive = s.jet1Alive;
    const prevJ2Alive = s.jet2Alive;
    s = processRespawns(s);
    if (s.jet1Alive && !prevJ1Alive) this.audio.playRespawn();
    if (s.jet2Alive && !prevJ2Alive) this.audio.playRespawn();

    // Low fuel warning
    if (
      this.frameCount % 30 === 0 &&
      ((s.jet1Alive && s.jet1Fuel < 50) || (s.jet2Alive && s.jet2Fuel < 50))
    ) {
      this.audio.playFuelLow();
    }

    // Check game over
    const gameOverResult = checkGameOver(s);
    if (gameOverResult.ended) {
      s = { ...s, phase: PHASE.FINISHED };
      this.gameState = s;
      this._handleGameOver();
      return;
    }

    // Tick timers
    s = tickTimers(s);

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

  _handleGameOver() {
    const winner = getWinner(this.gameState);

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
      }),
    );
    this._broadcastState();
    this._renderState();

    if (this.onGameEnd) {
      this.onGameEnd({
        score: {
          p1: this.gameState.score1,
          p2: this.gameState.score2,
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
      renderFrame(this.ctx, this.gameState, this.colors, performance.now(), this.particles);
    }
  }

  _playPhaseAudio(prevPhase, newPhase) {
    if (prevPhase === newPhase) return;
    if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
  }
}
