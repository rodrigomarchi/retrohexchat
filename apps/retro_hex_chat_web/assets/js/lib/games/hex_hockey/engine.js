/**
 * Hex Hockey — Main game engine.
 *
 * Extends GameEngine with hockey-specific game loop, input handling,
 * network sync, and lifecycle management.
 *
 * Host is authoritative: runs physics at 60fps, broadcasts state ~30Hz.
 * Peer sends input only and renders received state.
 */
import { log } from "../../logger.js";

import { GameEngine } from "../../game_engine.js";
import { createHockeyAI, normalizeHockeyAIDifficulty } from "./ai.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  EVENT,
  getMessageType,
  encodeGameState,
  decodeGameState,
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

const STATE_SEND_INTERVAL = 1; // broadcast every fixed step (60Hz)
const FACEOFF_GO_FRAMES = 30; // How long "GO!" stays visible
const HOCKEY_PREVENT_DEFAULT_KEYS = new Set([
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  " ",
  "Spacebar",
  "Shift",
  "w",
  "W",
  "a",
  "A",
  "s",
  "S",
  "d",
  "D",
]);

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
  static INPUT_BITS = { left: 0, right: 1, up: 2, down: 3, action: 4 };

  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {function|null} onGameEnd
   * @param {object} [options]
   * @param {"p2p_host"|"p2p_guest"|"solo"} [options.mode]
   * @param {object} [options.opponentController]
   * @param {"easy"|"normal"|"hard"|string} [options.difficulty]
   */
  constructor(canvas, channel, gameId, isHost, onGameEnd, options = {}) {
    super(canvas, channel, gameId, isHost, options);
    this.onGameEnd = onGameEnd || null;
    this.gameMode = resolveMode(gameId);

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
    this.difficulty = normalizeHockeyAIDifficulty(options.difficulty);
    this.opponentController =
      options.opponentController ||
      (this.mode === "solo" ? createHockeyAI({ difficulty: this.difficulty }) : null);

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

    if (this.mode === "solo") {
      this.peerReady = true;
      this.gameState = createInitialState(this.gameMode);
      this._invalidate();
    } else if (this.isHost) {
      this.gameState = createInitialState(this.gameMode);
      this._invalidate();
    } else {
      this._advertiseReady(encodeGameReady);
      this._invalidate();
    }
  }

  stop() {
    super.stop();
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
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

    switch (type) {
      case MSG_TYPE.GAME_READY:
        if (this.isHost && !this.peerReady) {
          this.beginMatch();
        }
        break;

      case MSG_TYPE.GAME_STATE:
        if (!this.isHost) {
          const decoded = decodeGameState(buf);
          if (decoded) {
            this._ingestSnapshot(decoded, () => {
              this.gameState = unpackState(decoded);
              this._handlePeerEvents(decoded.eventFlags);
              this._updatePuckTrail();
            });
            this.setKeyboardCaptured(
              decoded.phase !== PHASE.WAITING && decoded.phase !== PHASE.FINISHED,
            );
          }
        }
        break;

      case MSG_TYPE.GAME_END: {
        if (this.isHost) break;
        const result = decodeGameEnd(buf);
        if (result) {
          this.setKeyboardCaptured(false);
          this.audio.stopSuddenDeath();
          this.audio.playVictory();
          if (this.onGameEnd) {
            try {
              this.onGameEnd(result);
            } catch (error) {
              // The game-end callback (pushEvent) threw — keep the game stable.
              log.debug("[GameEngine] game-end callback failed", error);
            }
          }
        }
        break;
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

  _onRemoteInputChange(previous, current) {
    if (current.action && !previous.action) this.remoteActionHandled = false;
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
      case "Spacebar":
      case "Shift":
        return INPUT_KEY.ACTION;
      default:
        return null;
    }
  }

  // ── Game lifecycle ───────────────────────────────────────────

  beginMatch(options = {}) {
    if (
      !this.running ||
      !this.isHost ||
      !this.gameState ||
      this.gameState.phase !== PHASE.WAITING
    ) {
      return false;
    }

    if (options.difficulty) {
      this.difficulty = normalizeHockeyAIDifficulty(options.difficulty);
      if (
        !options.opponentController &&
        typeof this.opponentController?.setDifficulty === "function"
      ) {
        this.opponentController.setDifficulty(this.difficulty);
      }
    }
    if (options.opponentController) this.opponentController = options.opponentController;
    if (this.mode === "solo" && !this.opponentController) {
      this.opponentController = createHockeyAI({ difficulty: this.difficulty });
    }

    this.setKeyboardCaptured(true);
    this.peerReady = true;
    this._startCountdown();
    return true;
  }

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
    this._startSteps();
  }

  // ── Main game loop (host only) ───────────────────────────────

  _gameLoop() {
    this._step();
    if (this.goalFlash > 0) this.goalFlash--;
  }

  /** One step of the match. May return early on any phase. */
  _step() {
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
      this._invalidate();
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
      this._invalidate();
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
      this._invalidate();
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
      this._invalidate();
      if (this.frameCount % STATE_SEND_INTERVAL === 0) this._broadcastState();
      return;
    }

    // ── FINISHED phase ──
    if (state.phase === PHASE.FINISHED) {
      this._invalidate();
      this._broadcastState();
      this._stopSteps();
      this.setKeyboardCaptured(false);
      this.running = false;
      return;
    }

    // ── PLAYING / SUDDEN_DEATH phase (main gameplay) ──
    if (state.phase !== PHASE.PLAYING && state.phase !== PHASE.SUDDEN_DEATH) {
      this._invalidate();
      return;
    }

    // Update field players
    // Host = P1 (local), Peer = P2 (remote)
    this._updateOpponentInputs();
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

    this._invalidate();

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
    this._stopSteps();
    this.setKeyboardCaptured(false);
    const result = determineWinner(state);
    this.audio.stopSuddenDeath();
    this.audio.playVictory();

    this._sendCommand(encodeGameEnd(result));

    if (this.onGameEnd) {
      try {
        this.onGameEnd(result);
      } catch (error) {
        // The game-end callback (pushEvent) threw — keep teardown deterministic.
        log.debug("[GameEngine] game-end callback failed", error);
      }
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
    this._sendInputState();
  }

  _handleChannelClose() {
    this._stopSteps();
    this.setKeyboardCaptured(false);
    if (!this.gameState || this.gameState.phase === PHASE.FINISHED) return;
    this.gameState.phase = PHASE.FINISHED;
    this.audio.stopSuddenDeath();
    this._invalidate();
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
      } catch (error) {
        // The disconnect result callback (pushEvent) threw — do not lose it.
        log.debug("[GameEngine] game-end callback failed", error);
      }
    }
  }

  // ── Render / broadcast helpers ───────────────────────────────

  _renderState() {
    render(this.ctx, this.gameState, this.colors, this.frameCount, {
      iceParticles: this.iceParticles,
      puckTrail: this.puckTrail,
      goalFlash: this.goalFlash,
    });
  }

  _broadcastState() {
    if (!this.gameState) return;
    const packed = packState(this.gameState);
    this._sendState(encodeGameState(packed));
  }

  _updateOpponentInputs() {
    if (this.mode !== "solo" || typeof this.opponentController?.nextInputs !== "function") return;

    const previousAction = this.remoteInputs.action === true;
    const nextInputs = this.opponentController.nextInputs({
      state: this.gameState,
      difficulty: this.difficulty,
      player: 2,
    });

    if (!nextInputs) return;

    this.remoteInputs = {
      left: nextInputs.left === true,
      right: nextInputs.right === true,
      up: nextInputs.up === true,
      down: nextInputs.down === true,
      action: nextInputs.action === true,
    };

    if (this.remoteInputs.action && !previousAction) this.remoteActionHandled = false;
  }

  _shouldPreventDefaultForCapturedKey(event) {
    return HOCKEY_PREVENT_DEFAULT_KEYS.has(event.key);
  }
}
