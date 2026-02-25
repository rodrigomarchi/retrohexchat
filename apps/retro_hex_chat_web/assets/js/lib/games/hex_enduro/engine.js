/**
 * Hex Enduro — game engine wiring lifecycle, input, and network sync.
 * Host-authoritative: creator runs physics, peer renders received state.
 * @module games/hex_enduro_engine
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  EVENT,
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
  changeLane,
  updateLaneTransition,
  updateSpeed,
  activateTurbo,
  updateAICars,
  checkCollisions,
  checkOvertakes,
  checkPlayerOvertake,
  updateFuel,
  spawnFuelStations,
  updateFuelStations,
  updateSlipstream,
  updateWeather,
  updateZOffsets,
  tickTimers,
  checkGameOver,
  determineWinner,
  clearEvents,
  packState,
  unpackState,
} from "./physics.js";
import { getColors, render } from "./renderer.js";
import { HexEnduroAudio } from "./audio.js";

const MODE_MAP = {
  hex_enduro: GAME_MODE.CLASSIC_DUEL,
  hex_enduro_night: GAME_MODE.NIGHT_RACE,
  hex_enduro_sprint: GAME_MODE.SPRINT,
};

const STATE_SEND_INTERVAL = 2; // broadcast every 2 frames (~30Hz)

export class HexEnduroEngine extends GameEngine {
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd;
    this.mode = MODE_MAP[gameId] ?? GAME_MODE.CLASSIC_DUEL;
    this.seed = isHost ? (Math.random() * 0xffffffff) >>> 0 : 0;
    this.gameState = createInitialState(this.mode, this.seed);
    this.localInputs = { left: false, right: false, accel: false, brake: false, turbo: false };
    this.remoteInputs = { left: false, right: false, accel: false, brake: false, turbo: false };
    this._prevTurboLocal = false;
    this._prevTurboRemote = false;
    this._prevAiCars = [];
    this._prevP1Z = 0;
    this._prevP2Z = 0;
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new HexEnduroAudio();
    this.colors = null;
    this.peerReady = false;
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
    this.audio.stopEngineDrone();
    this.audio.destroy();
    this.running = false;
    this.channel.removeEventListener("message", this._boundOnMessage);
    document.removeEventListener("keydown", this._boundOnKeyDown);
    document.removeEventListener("keyup", this._boundOnKeyUp);
  }

  // ── Input Handling ──

  _mapKey(key) {
    switch (key) {
      case "ArrowLeft":
      case "a":
      case "A":
        return INPUT_KEY.LEFT;
      case "ArrowRight":
      case "d":
      case "D":
        return INPUT_KEY.RIGHT;
      case "ArrowUp":
      case "w":
      case "W":
        return INPUT_KEY.ACCEL;
      case "ArrowDown":
      case "s":
      case "S":
        return INPUT_KEY.BRAKE;
      case " ":
      case "Shift":
        return INPUT_KEY.TURBO;
      default:
        return null;
    }
  }

  _handleKeyDown(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (this.isHost) {
      this._setInput(this.localInputs, k, true);
    } else {
      this._safeSend(encodePlayerInput(k, true));
    }
  }

  _handleKeyUp(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (this.isHost) {
      this._setInput(this.localInputs, k, false);
    } else {
      this._safeSend(encodePlayerInput(k, false));
    }
  }

  _setInput(inputs, keyCode, pressed) {
    switch (keyCode) {
      case INPUT_KEY.LEFT:
        inputs.left = pressed;
        break;
      case INPUT_KEY.RIGHT:
        inputs.right = pressed;
        break;
      case INPUT_KEY.ACCEL:
        inputs.accel = pressed;
        break;
      case INPUT_KEY.BRAKE:
        inputs.brake = pressed;
        break;
      case INPUT_KEY.TURBO:
        inputs.turbo = pressed;
        break;
    }
  }

  _handleBlur() {
    this.localInputs = { left: false, right: false, accel: false, brake: false, turbo: false };
    if (!this.isHost) {
      for (const k of [
        INPUT_KEY.LEFT,
        INPUT_KEY.RIGHT,
        INPUT_KEY.ACCEL,
        INPUT_KEY.BRAKE,
        INPUT_KEY.TURBO,
      ]) {
        this._safeSend(encodePlayerInput(k, false));
      }
    }
  }

  // ── Network Messages ──

  _handleMessage(event) {
    const buf = event.data;
    if (!(buf instanceof ArrayBuffer)) return;
    const type = getMessageType(buf);

    if (this.isHost) {
      if (type === MSG_TYPE.PLAYER_INPUT) {
        const inp = decodePlayerInput(buf);
        if (inp) this._setInput(this.remoteInputs, inp.keyCode, inp.pressed);
      } else if (type === MSG_TYPE.GAME_READY) {
        if (!this.peerReady) {
          this.peerReady = true;
          this._startCountdown();
        }
      }
    } else {
      if (type === MSG_TYPE.GAME_STATE) {
        this._applyPeerState(decodeGameState(buf));
      } else if (type === MSG_TYPE.GAME_END) {
        const result = decodeGameEnd(buf);
        if (result) {
          this.gameState = { ...this.gameState, phase: PHASE.FINISHED };
          this._renderState();
          this.audio.stopEngineDrone();
          if (result.winner === (this.isHost ? 1 : 2)) {
            this.audio.playVictory();
          } else {
            this.audio.playGameOver();
          }
          if (this.onGameEnd) {
            try {
              this.onGameEnd({
                score: { p1: result.score1, p2: result.score2 },
                winner: result.winner,
              });
            } catch {
              /* callback error */
            }
          }
        }
      }
    }
  }

  _applyPeerState(decoded) {
    if (!decoded) return;

    // Bootstrap seed from first state
    if (this.seed === 0 && decoded.seed !== 0) {
      this.seed = decoded.seed;
    }

    // Convert flat protocol state to nested for rendering
    const nested = unpackState(decoded);

    // Preserve internal fields not sent over protocol
    nested.scrollOffset = this.gameState.scrollOffset || 0;
    nested.p1.targetLane = nested.p1.lane;
    nested.p2.targetLane = nested.p2.lane;

    // Play audio events
    this._playEventsAudio(decoded.events);

    this.gameState = nested;
    this._renderState();
  }

  // ── Countdown ──

  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._renderState();

    let count = 3;
    const tick = () => {
      if (!this.running) return;
      count -= 1;
      this.audio.playCountdown();
      if (count <= 0) {
        this.gameState.phase = PHASE.RACING;
        this._broadcastState();
        this.audio.startEngineDrone();
        this._startGameLoop();
      } else {
        this.gameState.countdown = count;
        this._broadcastState();
        this._renderState();
        this.phaseTimer = setTimeout(tick, 1000);
      }
    };

    this.phaseTimer = setTimeout(tick, 1000);
  }

  _startGameLoop() {
    if (this.animFrame) return; // guard against double-call
    this.frameCount = 0;
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  // ── Game Loop (Host Only) ──

  _gameLoop() {
    if (!this.running) return;
    let s = this.gameState;

    if (s.phase === PHASE.RACING) {
      s = clearEvents(s);

      // Save previous state for overtake detection
      this._prevAiCars = s.aiCars.map((c) => ({ ...c }));
      this._prevP1Z = s.p1.zOffset;
      this._prevP2Z = s.p2.zOffset;

      // Apply lane change inputs (P1 = host/local, P2 = peer/remote)
      if (this.localInputs.left) s = changeLane(s, "p1", -1);
      if (this.localInputs.right) s = changeLane(s, "p1", 1);
      if (this.remoteInputs.left) s = changeLane(s, "p2", -1);
      if (this.remoteInputs.right) s = changeLane(s, "p2", 1);

      // Turbo (edge-triggered)
      if (this.localInputs.turbo && !this._prevTurboLocal) {
        s = activateTurbo(s, "p1");
      }
      this._prevTurboLocal = this.localInputs.turbo;

      if (this.remoteInputs.turbo && !this._prevTurboRemote) {
        s = activateTurbo(s, "p2");
      }
      this._prevTurboRemote = this.remoteInputs.turbo;

      // Update lane transitions
      s = updateLaneTransition(s, "p1");
      s = updateLaneTransition(s, "p2");

      // Update speeds
      s = updateSpeed(s, "p1", { accel: this.localInputs.accel, brake: this.localInputs.brake });
      s = updateSpeed(s, "p2", { accel: this.remoteInputs.accel, brake: this.remoteInputs.brake });

      // Update z-offsets
      s = updateZOffsets(s);

      // AI traffic
      s = updateAICars(s);

      // Fuel
      s = updateFuel(s, "p1");
      s = updateFuel(s, "p2");
      s = spawnFuelStations(s);
      s = updateFuelStations(s);

      // Slipstream
      s = updateSlipstream(s);

      // Collisions
      s = checkCollisions(s);

      // Overtakes
      s = checkOvertakes(s, this._prevAiCars);
      s = checkPlayerOvertake(s, this._prevP1Z, this._prevP2Z);

      // Weather
      s = updateWeather(s);

      // Timers
      s = tickTimers(s);

      // Game over check
      s = checkGameOver(s);

      // Play audio events
      this._playEventsAudio(s.events);
      this.audio.updateEnginePitch((s.p1.speed + s.p2.speed) / 2);
    }

    this.gameState = s;
    this.frameCount += 1;

    // Broadcast state to peer
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    // Render
    this._renderState();

    // Check if game just ended
    if (s.phase === PHASE.FINISHED) {
      this._handleGameEnd();
      return;
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  // ── Broadcast ──

  _broadcastState() {
    try {
      const packed = packState(this.gameState);
      this._safeSend(encodeGameState(packed));
    } catch {
      /* encoding/send error — don't crash game loop */
    }
  }

  // ── Render ──

  _renderState() {
    const ctx = this.ctx;
    if (!ctx || !this.colors) return;
    render(ctx, this.gameState, this.colors, performance.now(), this.isHost);
  }

  // ── Audio Events ──

  _playEventsAudio(events) {
    if (events & EVENT.OVERTAKE_AI) this.audio.playOvertakeAI();
    if (events & EVENT.OVERTAKE_PLAYER) this.audio.playOvertakePlayer();
    if (events & EVENT.COLLISION) this.audio.playCollision();
    if (events & EVENT.FUEL_PICKUP) this.audio.playFuelPickup();
    if (events & EVENT.TURBO_ACTIVATE) this.audio.playTurbo();
    if (events & EVENT.WEATHER_CHANGE) this.audio.playWeatherChange();
  }

  // ── Game End ──

  _handleGameEnd() {
    this.audio.stopEngineDrone();
    const winner = determineWinner(this.gameState);
    if (winner === 1) {
      this.audio.playVictory();
    } else {
      this.audio.playGameOver();
    }

    const result = {
      score1: this.gameState.p1.score,
      score2: this.gameState.p2.score,
      winner,
    };

    // Send game end to peer
    this._safeSend(encodeGameEnd(result));

    // Notify LiveView
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: result.score1, p2: result.score2 },
          winner: result.winner,
        });
      } catch {
        /* callback error */
      }
    }
  }

  _handleChannelClose() {
    if (this.running && this.gameState.phase !== PHASE.FINISHED) {
      this.gameState.phase = PHASE.FINISHED;

      // Stop game loop
      if (this.animFrame) {
        cancelAnimationFrame(this.animFrame);
        this.animFrame = null;
      }

      // Clear countdown timer
      if (this.phaseTimer) {
        clearTimeout(this.phaseTimer);
        this.phaseTimer = null;
      }

      this._renderState();
      this.audio.stopEngineDrone();
      this.audio.playGameOver();

      // Notify LiveView of disconnect
      if (this.onGameEnd) {
        try {
          this.onGameEnd({
            score: { p1: this.gameState.p1.score, p2: this.gameState.p2.score },
            winner: 0, // draw on disconnect
          });
        } catch {
          /* callback error */
        }
      }
    }
  }
}
