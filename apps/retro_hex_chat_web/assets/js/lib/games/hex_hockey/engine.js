/**
 * Hex Hockey — Main game engine.
 *
 * Extends GameEngine with hockey-specific game loop, input handling,
 * network sync, and lifecycle management.
 *
 * Host is authoritative: runs physics at 60fps, broadcasts state ~30Hz.
 * Peer sends input only and renders received state.
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  EVENT,
  getMessageType,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
} from "./protocol.js";
import {
  createInitialState,
  packState,
  unpackState,
  updatePlayer,
  updateGoalie,
  updatePuck,
  checkCapture,
  checkGoalieBlock,
  handleShoot,
  handleTackle,
  checkGoal,
  checkPuckStuck,
  resetForFaceoff,
  advancePeriod,
  checkShowdownWin,
  determineWinner,
  COUNTDOWN_FRAME_INTERVAL,
  GOAL_CELEBRATION_FRAMES,
} from "./physics.js";
import { render, readColors, generateIceParticles } from "./renderer.js";
import { HexHockeyAudio } from "./audio.js";

const STATE_SEND_INTERVAL = 2; // Broadcast every 2 frames (~30Hz)
const FACEOFF_GO_FRAMES = 30; // How long "GO!" stays visible

/**
 * Map gameId string to GAME_MODE enum.
 */
function resolveMode(gameId) {
  switch (gameId) {
    case "hex_hockey_blitz":
      return GAME_MODE.BLITZ;
    case "hex_hockey_showdown":
      return GAME_MODE.SHOWDOWN;
    default:
      return GAME_MODE.CLASSIC;
  }
}

export class HexHockeyEngine extends GameEngine {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {function|null} onGameEnd
   */
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd || null;
    this.mode = resolveMode(gameId);

    this.gameState = null;
    this.localInputs = { left: false, right: false, up: false, down: false, action: false };
    this.remoteInputs = { left: false, right: false, up: false, down: false, action: false };
    this.frameCount = 0;
    this.peerReady = false;
    this.phaseTimer = 0;
    this.faceoffGoTimer = 0;
    this.actionHandled = false;
    this.remoteActionHandled = false;

    this.audio = new HexHockeyAudio();
    this.colors = null;
    this.iceParticles = null;

    // Puck trail for rendering
    this.puckTrail = [];
    this.goalFlash = 0;

    // Connection resilience
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();

    this.colors = readColors(this.canvas);
    this.iceParticles = generateIceParticles(40);

    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.isHost) {
      this.gameState = createInitialState(this.mode);
      this._renderState();
    } else {
      this._safeSend(encodeGameReady());
      this._renderState();
    }
  }

  stop() {
    super.stop();
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    this.audio.destroy();
    this.localInputs = { left: false, right: false, up: false, down: false, action: false };
    this.remoteInputs = { left: false, right: false, up: false, down: false, action: false };
    this.peerReady = false;
    this.frameCount = 0;
    this.phaseTimer = 0;
    this.faceoffGoTimer = 0;
    this.puckTrail = [];
    this.goalFlash = 0;
  }

  // ── Network messages ─────────────────────────────────────────

  _handleMessage(event) {
    if (!(event.data instanceof ArrayBuffer)) return;
    const buf = event.data;
    const type = getMessageType(buf);

    if (type === MSG_TYPE.GAME_READY && this.isHost) {
      if (this.peerReady) return;
      this.peerReady = true;
      this._startCountdown();
    } else if (type === MSG_TYPE.GAME_STATE && !this.isHost) {
      const decoded = decodeGameState(buf);
      if (decoded) {
        this.gameState = unpackState(decoded);
        this._handlePeerEvents(decoded.eventFlags);
        this._updatePuckTrail();
        this._renderState();
      }
    } else if (type === MSG_TYPE.PLAYER_INPUT && this.isHost) {
      const input = decodePlayerInput(buf);
      if (input) {
        this._applyRemoteInput(input);
      }
    } else if (type === MSG_TYPE.GAME_END && !this.isHost) {
      const result = decodeGameEnd(buf);
      if (result) {
        this.audio.stopSuddenDeath();
        this.audio.playVictory();
        if (this.onGameEnd) {
          this.onGameEnd(result);
        }
      }
    }
  }

  _applyRemoteInput(input) {
    if (input.key === INPUT_KEY.LEFT) this.remoteInputs.left = input.pressed;
    else if (input.key === INPUT_KEY.RIGHT) this.remoteInputs.right = input.pressed;
    else if (input.key === INPUT_KEY.UP) this.remoteInputs.up = input.pressed;
    else if (input.key === INPUT_KEY.DOWN) this.remoteInputs.down = input.pressed;
    else if (input.key === INPUT_KEY.ACTION) {
      this.remoteInputs.action = input.pressed;
      if (input.pressed) this.remoteActionHandled = false;
    }
  }

  // ── Input handling ───────────────────────────────────────────

  _handleKeyDown(event) {
    const key = this._mapKey(event);
    if (key === null) return;
    event.preventDefault();

    if (key === INPUT_KEY.LEFT) this.localInputs.left = true;
    else if (key === INPUT_KEY.RIGHT) this.localInputs.right = true;
    else if (key === INPUT_KEY.UP) this.localInputs.up = true;
    else if (key === INPUT_KEY.DOWN) this.localInputs.down = true;
    else if (key === INPUT_KEY.ACTION) {
      this.localInputs.action = true;
      this.actionHandled = false;
    }

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(key, true));
    }
  }

  _handleKeyUp(event) {
    const key = this._mapKey(event);
    if (key === null) return;
    event.preventDefault();

    if (key === INPUT_KEY.LEFT) this.localInputs.left = false;
    else if (key === INPUT_KEY.RIGHT) this.localInputs.right = false;
    else if (key === INPUT_KEY.UP) this.localInputs.up = false;
    else if (key === INPUT_KEY.DOWN) this.localInputs.down = false;
    else if (key === INPUT_KEY.ACTION) this.localInputs.action = false;

    if (!this.isHost) {
      this._safeSend(encodePlayerInput(key, false));
    }
  }

  _mapKey(event) {
    switch (event.key) {
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
        return INPUT_KEY.UP;
      case "ArrowDown":
      case "s":
      case "S":
        return INPUT_KEY.DOWN;
      case " ":
      case "Shift":
        return INPUT_KEY.ACTION;
      default:
        return null;
    }
  }

  // ── Game lifecycle ───────────────────────────────────────────

  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdownValue = 3;
    this.phaseTimer = COUNTDOWN_FRAME_INTERVAL;
    resetForFaceoff(this.gameState, null);
    this.audio.playCountdownTick();
    this._broadcastState();
    this._startGameLoop();
  }

  _startGameLoop() {
    if (this.animFrame) return;
    const loop = () => {
      if (!this.running) return;
      this._gameLoop();
      this.animFrame = requestAnimationFrame(loop);
    };
    this.animFrame = requestAnimationFrame(loop);
  }

  // ── Main game loop (host only) ───────────────────────────────

  _gameLoop() {
    if (!this.isHost || !this.gameState) return;

    this.frameCount++;
    const state = this.gameState;
    state.eventFlags = 0;
    state.frameCount = this.frameCount;

    // ── COUNTDOWN phase ──
    if (state.phase === PHASE.COUNTDOWN) {
      this.phaseTimer--;
      if (this.phaseTimer <= 0) {
        state.countdownValue--;
        if (state.countdownValue <= 0) {
          state.phase = PHASE.FACE_OFF;
          state.countdownValue = 0;
          this.faceoffGoTimer = FACEOFF_GO_FRAMES;
          state.eventFlags |= EVENT.WHISTLE;
          this.audio.playGo();
        } else {
          this.phaseTimer = COUNTDOWN_FRAME_INTERVAL;
          this.audio.playCountdownTick();
        }
      }
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── FACE_OFF phase (brief "GO!" display then transition to playing) ──
    if (state.phase === PHASE.FACE_OFF) {
      this.faceoffGoTimer--;
      if (this.faceoffGoTimer <= 0) {
        const maxPeriods = state.mode === GAME_MODE.BLITZ ? 1 : 3;
        const isSudden = state.mode !== GAME_MODE.SHOWDOWN && state.period > maxPeriods;
        state.phase = isSudden ? PHASE.SUDDEN_DEATH : PHASE.PLAYING;
        if (state.phase === PHASE.SUDDEN_DEATH) {
          this.audio.playSuddenDeath();
        }
        this.audio.playFaceoffWhistle();
      }
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── GOAL_CELEBRATION phase ──
    if (state.phase === PHASE.GOAL_CELEBRATION) {
      state.celebrationFrames--;
      this.goalFlash = state.celebrationFrames;
      if (state.celebrationFrames <= 0) {
        // Check if game is over (showdown win check)
        if (checkShowdownWin(state)) {
          state.phase = PHASE.FINISHED;
          this._handleGameFinished(state);
        } else {
          // Set up next face-off
          state.phase = PHASE.COUNTDOWN;
          state.countdownValue = 3;
          this.phaseTimer = COUNTDOWN_FRAME_INTERVAL;
          resetForFaceoff(state, null);
          this.audio.playCountdownTick();
        }
      }
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── PERIOD_BREAK phase ──
    if (state.phase === PHASE.PERIOD_BREAK) {
      state.periodBreakFrames--;
      if (state.periodBreakFrames <= 0) {
        state.phase = PHASE.COUNTDOWN;
        state.countdownValue = 3;
        this.phaseTimer = COUNTDOWN_FRAME_INTERVAL;
        resetForFaceoff(state, null);
        this.audio.playCountdownTick();
      }
      this._renderState();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── FINISHED phase ──
    if (state.phase === PHASE.FINISHED) {
      this._renderState();
      this._broadcastState();
      this.running = false;
      return;
    }

    // ── PLAYING / SUDDEN_DEATH phase (main gameplay) ──
    if (state.phase !== PHASE.PLAYING && state.phase !== PHASE.SUDDEN_DEATH) {
      this._renderState();
      return;
    }

    // Update field players
    // Host = P1 (local), Peer = P2 (remote)
    updatePlayer(state, this.localInputs, true);
    updatePlayer(state, this.remoteInputs, false);

    // Handle action (shoot or tackle) — one-shot per press
    if (this.localInputs.action && !this.actionHandled) {
      this.actionHandled = true;
      const evts = this._handleAction(state, true);
      state.eventFlags |= evts;
    }
    if (this.remoteInputs.action && !this.remoteActionHandled) {
      this.remoteActionHandled = true;
      const evts = this._handleAction(state, false);
      state.eventFlags |= evts;
    }

    // Update goalies (AI)
    updateGoalie(state, true);
    updateGoalie(state, false);

    // Update puck physics
    const puckEvents = updatePuck(state);
    state.eventFlags |= puckEvents;

    // Check goalie block
    const blockEvents = checkGoalieBlock(state);
    state.eventFlags |= blockEvents;

    // Check capture
    const captureEvents = checkCapture(state);
    state.eventFlags |= captureEvents;

    // Check goal
    const scored = checkGoal(state);
    if (scored) {
      if (scored === "p1") {
        state.scoreP1++;
        state.eventFlags |= EVENT.GOAL_P1;
      } else {
        state.scoreP2++;
        state.eventFlags |= EVENT.GOAL_P2;
      }
      state.phase = PHASE.GOAL_CELEBRATION;
      state.celebrationFrames = GOAL_CELEBRATION_FRAMES;
      this.goalFlash = GOAL_CELEBRATION_FRAMES;
      this.audio.playGoal();
    }

    // Check puck stuck
    if (checkPuckStuck(state)) {
      state.eventFlags |= EVENT.FACE_OFF;
      state.phase = PHASE.COUNTDOWN;
      state.countdownValue = 3;
      this.phaseTimer = COUNTDOWN_FRAME_INTERVAL;
      resetForFaceoff(state, null);
      this.audio.playFaceoffWhistle();
    }

    // Timer countdown (not in sudden death or showdown)
    if (state.phase === PHASE.PLAYING && state.timerFrames > 0) {
      state.timerFrames--;
      if (state.timerFrames <= 0) {
        // Period end
        const periodEvents = advancePeriod(state);
        state.eventFlags |= periodEvents;

        if (state.phase === PHASE.PERIOD_BREAK) {
          this.audio.playPeriodBuzzer();
        } else if (periodEvents & EVENT.SUDDEN_DEATH) {
          state.phase = PHASE.COUNTDOWN;
          state.countdownValue = 3;
          this.phaseTimer = COUNTDOWN_FRAME_INTERVAL;
          this.audio.playPeriodBuzzer();
        } else if (state.phase === PHASE.FINISHED) {
          this._handleGameFinished(state);
        }
      }
    }

    // Update puck trail
    this._updatePuckTrail();

    // Audio events
    this._handleAudioEvents(state.eventFlags);

    this._renderState();

    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }
  }

  // ── Action handling (shoot or tackle) ─────────────────────────

  _handleAction(state, isP1) {
    const player = isP1 ? state.p1 : state.p2;

    if (player.hasPuck) {
      return handleShoot(state, isP1);
    }
    return handleTackle(state, isP1);
  }

  // ── Audio events ─────────────────────────────────────────────

  _handleAudioEvents(events) {
    if (events & EVENT.GOAL_P1 || events & EVENT.GOAL_P2) {
      // Goal sound handled separately in goal detection
      return;
    }
    if (events & EVENT.SHOT) this.audio.playShot();
    if (events & EVENT.WALL_BOUNCE) this.audio.playWallBounce();
    if (events & EVENT.GOALIE_BLOCK) this.audio.playGoalieBlock();
    if (events & EVENT.TACKLE_SUCCESS) this.audio.playTackleSuccess();
    if (events & EVENT.TACKLE_FAIL) this.audio.playTackleFail();
    if (events & EVENT.CAPTURE) this.audio.playCapture();
    if (events & EVENT.WHISTLE) this.audio.playFaceoffWhistle();
  }

  _handlePeerEvents(events) {
    // Same audio triggers for peer
    if (events & EVENT.GOAL_P1 || events & EVENT.GOAL_P2) {
      this.audio.playGoal();
      this.goalFlash = GOAL_CELEBRATION_FRAMES;
    }
    if (events & EVENT.SHOT) this.audio.playShot();
    if (events & EVENT.WALL_BOUNCE) this.audio.playWallBounce();
    if (events & EVENT.GOALIE_BLOCK) this.audio.playGoalieBlock();
    if (events & EVENT.TACKLE_SUCCESS) this.audio.playTackleSuccess();
    if (events & EVENT.TACKLE_FAIL) this.audio.playTackleFail();
    if (events & EVENT.CAPTURE) this.audio.playCapture();
    if (events & EVENT.PERIOD_END) this.audio.playPeriodBuzzer();
    if (events & EVENT.SUDDEN_DEATH) this.audio.playSuddenDeath();
    if (events & EVENT.WHISTLE) this.audio.playFaceoffWhistle();
  }

  // ── Puck trail ───────────────────────────────────────────────

  _updatePuckTrail() {
    if (!this.gameState) return;
    const { puck } = this.gameState;
    if (puck.possessedBy !== 0) {
      this.puckTrail = [];
      return;
    }
    this.puckTrail.push({ x: puck.x, y: puck.y });
    if (this.puckTrail.length > 8) {
      this.puckTrail.shift();
    }
  }

  // ── Game end ─────────────────────────────────────────────────

  _handleGameFinished(state) {
    const result = determineWinner(state);
    this.audio.stopSuddenDeath();
    this.audio.playVictory();

    this._safeSend(encodeGameEnd(result));

    if (this.onGameEnd) {
      this.onGameEnd(result);
    }
  }

  // ── Connection resilience ───────────────────────────────────

  _handleBlur() {
    this.localInputs = {
      left: false,
      right: false,
      up: false,
      down: false,
      action: false,
    };
  }

  _handleChannelClose() {
    if (!this.gameState || this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this.audio.stopSuddenDeath();
    this._renderState();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          winner: "draw",
          score_p1: this.gameState.scoreP1,
          score_p2: this.gameState.scoreP2,
          periods: this.gameState.period,
          mode: this.gameState.mode,
          disconnected: true,
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  // ── Render / broadcast helpers ───────────────────────────────

  _renderState() {
    // Decay goal flash
    if (this.goalFlash > 0) this.goalFlash--;

    render(this.ctx, this.gameState, this.colors, this.frameCount, {
      iceParticles: this.iceParticles,
      puckTrail: this.puckTrail,
      goalFlash: this.goalFlash,
    });
  }

  _broadcastState() {
    if (!this.gameState) return;
    const packed = packState(this.gameState);
    this._safeSend(encodeGameState(packed));
  }
}
