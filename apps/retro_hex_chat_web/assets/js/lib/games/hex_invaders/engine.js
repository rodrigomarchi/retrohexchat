/**
 * Hex Invaders — game engine wiring lifecycle, input, and network sync.
 * Host-authoritative: creator runs physics, peer renders received state.
 * @module games/hex_invaders_engine
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
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
  createWave,
  moveCannon,
  fireMissile,
  updateMissiles,
  moveAliens,
  spawnBombs,
  updateBombs,
  checkMissileAlienHits,
  checkMissileUFOHit,
  checkBombCannonHits,
  checkBombShieldHits,
  checkAlienReachedGround,
  processDropQueue,
  updateUFO,
  updateCombos,
  checkWaveClear,
  checkGameOver,
  tickTimers,
  clearEvents,
} from "./physics.js";
import { getColors, render } from "./renderer.js";
import { HexInvadersAudio } from "./audio.js";

const MODE_MAP = {
  hex_invaders: GAME_MODE.INVASION_WAR,
  hex_invaders_coop: GAME_MODE.COOP,
  hex_invaders_blitz: GAME_MODE.BLITZ,
};

const STATE_SEND_INTERVAL = 2; // broadcast every 2 frames (~30Hz)
const WAVE_CLEAR_FRAMES = 120; // 2 sec overlay
const WAVE_START_FRAMES = 60; // 1 sec overlay

export class HexInvadersEngine extends GameEngine {
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd;
    this.mode = MODE_MAP[gameId] ?? GAME_MODE.INVASION_WAR;
    this.seed = isHost ? (Math.random() * 0xffffffff) >>> 0 : 0;
    this.gameState = createInitialState(this.mode, this.seed);
    this.localInputs = { left: false, right: false, fire: false };
    this.remoteInputs = { left: false, right: false, fire: false };
    this._localFirePressed = false;
    this._remoteFirePressed = false;
    this.frameCount = 0;
    this.phaseTimer = null;
    this.audio = new HexInvadersAudio();
    this.colors = null;
    this.peerReady = false;
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return; // double-start guard
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
      case " ":
        return INPUT_KEY.FIRE;
      default:
        return null;
    }
  }

  _handleKeyDown(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (this.isHost) {
      if (k === INPUT_KEY.LEFT) this.localInputs.left = true;
      else if (k === INPUT_KEY.RIGHT) this.localInputs.right = true;
      else if (k === INPUT_KEY.FIRE) this.localInputs.fire = true;
    } else {
      this._safeSend(encodePlayerInput(k, true));
    }
  }

  _handleKeyUp(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (this.isHost) {
      if (k === INPUT_KEY.LEFT) this.localInputs.left = false;
      else if (k === INPUT_KEY.RIGHT) this.localInputs.right = false;
      else if (k === INPUT_KEY.FIRE) this.localInputs.fire = false;
    } else {
      this._safeSend(encodePlayerInput(k, false));
    }
  }

  _handleBlur() {
    this.localInputs = { left: false, right: false, fire: false };
    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.LEFT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.RIGHT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.FIRE, false));
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
        if (!inp) return;
        if (inp.keyCode === INPUT_KEY.LEFT) {
          this.remoteInputs.left = inp.pressed;
        } else if (inp.keyCode === INPUT_KEY.RIGHT) {
          this.remoteInputs.right = inp.pressed;
        } else if (inp.keyCode === INPUT_KEY.FIRE) {
          this.remoteInputs.fire = inp.pressed;
        }
      } else if (type === MSG_TYPE.GAME_READY) {
        if (!this.peerReady) {
          this.peerReady = true;
          this._startCountdown();
        }
      }
    } else {
      // Peer
      if (type === MSG_TYPE.GAME_STATE) {
        this._applyPeerState(decodeGameState(buf));
      } else if (type === MSG_TYPE.GAME_END) {
        const result = decodeGameEnd(buf);
        if (result) {
          this.gameState = {
            ...this.gameState,
            phase: PHASE.FINISHED,
          };
          this._renderState();
          if (this.onGameEnd) {
            try {
              this.onGameEnd({
                score: { p1: result.score1, p2: result.score2 },
                winner: result.winner,
              });
            } catch {
              // callback error — ignore
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
      this.gameState = createInitialState(this.mode, this.seed);
    }

    // Copy all decoded fields into gameState, preserving _shieldPositions
    const shieldPositions = this.gameState._shieldPositions;
    Object.assign(this.gameState, decoded);
    this.gameState._shieldPositions = shieldPositions;

    this._renderState();
  }

  // ── Countdown & Phase Transitions ──

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
        this.gameState = createWave(this.gameState, 1);
        this.gameState.phase = PHASE.PLAYING;
        this._broadcastState();
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
    this.frameCount = 0;
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  // ── Game Loop (Host Only) ──

  _gameLoop() {
    if (!this.running) return;
    let s = this.gameState;

    if (s.phase === PHASE.PLAYING) {
      s = clearEvents(s);

      // Apply inputs — P1 = host (local), P2 = peer (remote)
      if (this.localInputs.left) s = moveCannon(s, 1, -1);
      if (this.localInputs.right) s = moveCannon(s, 1, 1);
      if (this.remoteInputs.left) s = moveCannon(s, 2, -1);
      if (this.remoteInputs.right) s = moveCannon(s, 2, 1);

      // Edge-trigger fire
      if (this.localInputs.fire && !this._localFirePressed) {
        s = fireMissile(s, 1);
        this.audio.playFire();
      }
      this._localFirePressed = this.localInputs.fire;

      if (this.remoteInputs.fire && !this._remoteFirePressed) {
        s = fireMissile(s, 2);
        this.audio.playFire();
      }
      this._remoteFirePressed = this.remoteInputs.fire;

      // Alien movement
      s = moveAliens(s, 1);
      if (s.mode !== GAME_MODE.COOP) {
        s = moveAliens(s, 2);
      }

      // Play march on alien move (when timer resets)
      if (s.alien1MoveTimer > this.gameState.alien1MoveTimer + 5) {
        this.audio.playMarch();
      }

      // Spawn and update projectiles
      s = spawnBombs(s);
      s = updateMissiles(s);
      s = updateBombs(s);
      s = updateUFO(s);

      // Collisions
      s = checkMissileAlienHits(s);
      s = checkMissileUFOHit(s);
      s = checkBombShieldHits(s);
      s = checkBombCannonHits(s);
      s = checkAlienReachedGround(s);

      // Drop queue
      s = processDropQueue(s);

      // Combos
      s = updateCombos(s);

      // Audio events
      this._playEventSounds(s);

      // Check game over
      const result = checkGameOver(s);
      if (result.ended) {
        s.phase = PHASE.FINISHED;
        this.gameState = s;
        this._handleGameFinished(result);
        return;
      }

      // Check wave clear
      if (checkWaveClear(s)) {
        s.phase = PHASE.WAVE_CLEAR;
        s.events.waveCleared = true;
        this.audio.playWaveClear();
        this.gameState = s;
        this._broadcastState();
        this._renderState();
        this._handleWaveClear();
        return;
      }

      // Tick timers
      s = tickTimers(s);

      this.gameState = s;
    }

    this._renderState();
    this.frameCount += 1;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  _playEventSounds(s) {
    if (s.events.alienKill) this.audio.playAlienDestroyed();
    if (s.events.armoredHit) this.audio.playArmoredClang();
    if (s.events.cannonHit) this.audio.playCannonHit();
    if (s.events.shieldHit) this.audio.playShieldHit();
    if (s.events.ufoKill) this.audio.playUFODestroyed();
    if (s.events.ufoAppear) this.audio.playUFOAppear();
    if (s.events.combo > 0) this.audio.playCombo(s.events.combo);
    if (s.events.dropLand) this.audio.playDropLand();
    if (s.events.invaded) this.audio.playInvaded();
  }

  // ── Wave Transitions ──

  _handleWaveClear() {
    this.phaseTimer = setTimeout(
      () => {
        if (!this.running) return;
        const maxWaves = this.gameState.mode === GAME_MODE.BLITZ ? 5 : 10;
        const nextWave = this.gameState.wave + 1;

        if (nextWave > maxWaves) {
          // Game over — survived all waves
          const result = checkGameOver({
            ...this.gameState,
            wave: nextWave,
            phase: PHASE.PLAYING,
          });
          this.gameState.phase = PHASE.FINISHED;
          this._handleGameFinished(
            result.ended
              ? result
              : {
                  ended: true,
                  winner: this.gameState.score1 >= this.gameState.score2 ? 1 : 2,
                },
          );
          return;
        }

        this.gameState = createWave(this.gameState, nextWave);
        this.gameState.phase = PHASE.WAVE_START;
        this._broadcastState();
        this._renderState();

        this.phaseTimer = setTimeout(
          () => {
            if (!this.running) return;
            this.gameState.phase = PHASE.PLAYING;
            this.animFrame = requestAnimationFrame(this._boundGameLoop);
          },
          (WAVE_START_FRAMES / 60) * 1000,
        );
      },
      (WAVE_CLEAR_FRAMES / 60) * 1000,
    );
  }

  // ── Game End ──

  _handleGameFinished(result) {
    this._broadcastState();
    this._renderState();

    const endBuf = encodeGameEnd({
      score1: this.gameState.score1,
      score2: this.gameState.score2,
      winner: result.winner,
    });
    this._safeSend(endBuf);

    if (result.winner > 0) {
      this.audio.playVictory();
    } else {
      this.audio.playInvaded();
    }

    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.score1, p2: this.gameState.score2 },
          winner: result.winner,
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    if (this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this._renderState();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.score1, p2: this.gameState.score2 },
          winner: 0, // no winner on disconnect
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  // ── Rendering ──

  _renderState() {
    if (this.colors) {
      render(this.ctx, this.gameState, this.colors, performance.now());
    }
  }

  // ── State Broadcasting ──

  _broadcastState() {
    this._safeSend(encodeGameState(this.gameState));
  }
}
