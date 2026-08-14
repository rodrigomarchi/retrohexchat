import { log } from "./logger.js";
import { t, jt } from "./i18n.js";
import { gameColor } from "./game_colors.js";
import { FrameClock } from "./games/frame_clock.js";
import { SnapshotInterpolator } from "./games/interpolator.js";
import { GameTelemetry } from "./games/telemetry.js";
import { normalizeGameTransport } from "./games/transport.js";
import {
  BASE_MSG,
  decodeInputEdge,
  decodeInputState,
  encodeInputEdge,
  encodeInputState,
  isNewerSeq,
  packInputs,
  unpackInputs,
} from "./games/net_protocol.js";

/**
 * Game engine base — owns the frame clock, the presentation loop, input
 * transport and telemetry. Each concrete game provides its own binary state
 * protocol and its own physics.
 *
 * The host simulates and the guest draws, so the two sides run different work
 * off one loop: the host advances fixed steps and broadcasts snapshots, the
 * guest interpolates toward the snapshots it receives. Both paint at display
 * rate.
 *
 * @module game_engine
 */

/**
 * Above this much queued data the channel is already behind, and another
 * snapshot would only add latency that never drains. State is dropped instead —
 * the next snapshot supersedes it anyway.
 */
export const SEND_HIGH_WATER_BYTES = 64 * 1024;

/** How many times a one-shot command is repeated on the unreliable channel. */
const COMMAND_REPEATS = 3;

/** Spacing between the repeats of a one-shot command. */
const COMMAND_REPEAT_MS = 40;

/** Frames an all-released input mask keeps being restated after the release. */
const IDLE_INPUT_RESTATES = 10;

/** How often the guest re-announces itself until the host answers. */
const READY_RETRY_MS = 250;

/** Elements whose keystrokes belong to the user, never to the game. */
const TEXT_ENTRY_TAGS = new Set(["INPUT", "TEXTAREA", "SELECT"]);

/** Keyboard listener options shared by add/removeEventListener. */
const KEYBOARD_CAPTURE_OPTIONS = true;

/**
 * Base game engine.
 *
 * Subclass contract:
 * - `static INPUT_BITS` maps this game's held inputs to bit positions; the base
 *   then owns input transport entirely. Games whose input is a discrete command
 *   leave it empty and call `_sendInputEdge()`.
 * - `static INTERPOLATION` declares the state keys that read as motion, so the
 *   guest can smooth them between snapshots.
 * - `_gameLoop()` runs exactly one simulation step. Never schedule the next one
 *   — call `_startSteps()` / `_stopSteps()` to control the loop.
 * - `_renderState()` draws. Never call it directly; call `_invalidate()`.
 * - `_ingestSnapshot(decoded)` applies an authoritative snapshot on the guest.
 * - `_sendState(data)` for snapshots, `_sendCommand(data)` for one-shots.
 */
export class GameEngine {
  /** @type {Record<string, number>} held-input name to bit position */
  static INPUT_BITS = {};

  /** @type {{keys: string[], snapDistance?: number}} guest-side smoothing */
  static INTERPOLATION = { keys: [] };

  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel|object} channel
   * @param {string} gameId
   * @param {boolean} isHost
   * @param {object} [options]
   * @param {"p2p_host"|"p2p_guest"|"solo"} [options.mode]
   */
  constructor(canvas, channel, gameId, isHost, options = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.transport = normalizeGameTransport(channel);
    this.channel = this.transport;
    this.gameId = gameId;
    this.isHost = isHost;
    this.mode = options.mode || (isHost ? "p2p_host" : "p2p_guest");
    this.running = false;
    this.animFrame = null;

    /** Set by the host hook; receives periodic telemetry samples. */
    this.onTelemetry = null;

    this.localInputs = {};
    this.remoteInputs = {};

    const interpolation = new.target.INTERPOLATION || { keys: [] };

    this._clock = new FrameClock();
    this._interpolator = new SnapshotInterpolator(interpolation);
    this._telemetry = new GameTelemetry({
      gameId,
      isHost,
      onSample: (sample) => {
        if (this.onTelemetry) this.onTelemetry(sample);
      },
    });

    this._stepping = false;
    this._renderPending = true;
    this._inputSeq = 0;
    this._lastSentMask = 0;
    this._idleRestatesLeft = 0;
    this._lastRemoteInputSeq = null;
    this._lastRemoteEdgeSeq = null;
    this._commandTimers = new Set();
    this._readyTimer = null;
    this._readyEncoder = null;
    this._keyboardCaptured = options.captureKeyboard === true;

    this._boundOnMessage = this._onChannelMessage.bind(this);
    this._boundOnKeyDown = this._onKeyDown.bind(this);
    this._boundOnKeyUp = this._onKeyUp.bind(this);
    this._boundPump = this._pump.bind(this);
  }

  /** @returns {void} */
  start() {
    if (this.running) return;
    this.running = true;

    this.channel.addEventListener("message", this._boundOnMessage);
    window.addEventListener("keydown", this._boundOnKeyDown, KEYBOARD_CAPTURE_OPTIONS);
    window.addEventListener("keyup", this._boundOnKeyUp, KEYBOARD_CAPTURE_OPTIONS);

    const now = this._now();
    this._clock.reset(now);
    this._telemetry.start(now);
    this.animFrame = requestAnimationFrame(this._boundPump);
  }

  /** @returns {void} */
  stop() {
    this.running = false;
    this._stepping = false;
    this.setKeyboardCaptured(false);

    if (this.animFrame) {
      cancelAnimationFrame(this.animFrame);
      this.animFrame = null;
    }

    this._clearReadyHandshake();

    for (const timer of this._commandTimers) clearTimeout(timer);
    this._commandTimers.clear();

    this.channel.removeEventListener("message", this._boundOnMessage);
    window.removeEventListener("keydown", this._boundOnKeyDown, KEYBOARD_CAPTURE_OPTIONS);
    window.removeEventListener("keyup", this._boundOnKeyUp, KEYBOARD_CAPTURE_OPTIONS);

    this._telemetry.stop();

    // Every game holds an AudioContext, and each one holds a real-time audio
    // thread for as long as it lives. Leaving them open across matches starved
    // the call's own audio and eventually hit the browser's per-page ceiling.
    if (this.audio && typeof this.audio.dispose === "function") {
      this.audio.dispose();
    }
  }

  // ── Simulation loop ──

  /**
   * Begin advancing the simulation at a fixed 60 Hz, independent of how often
   * the browser paints.
   * @returns {void}
   */
  _startSteps() {
    if (this._stepping) return;
    this._clock.reset(this._now());
    this._stepping = true;
  }

  /** @returns {void} */
  _stopSteps() {
    this._stepping = false;
  }

  /** @returns {boolean} */
  get stepping() {
    return this._stepping;
  }

  /**
   * Request a repaint on the next frame. Repaints coalesce, so calling this
   * many times within one frame costs one draw.
   * @returns {void}
   */
  _invalidate() {
    this._renderPending = true;
  }

  /**
   * The presentation loop: one rAF callback driving fixed-rate simulation,
   * guest-side interpolation, input transport and a single coalesced repaint.
   * @param {number} now
   * @returns {void}
   */
  _pump(now) {
    if (!this.running) return;
    this.animFrame = requestAnimationFrame(this._boundPump);

    const steps = this._clock.advance(now);

    if (steps > 0) {
      if (this._stepping) {
        for (let i = 0; i < steps && this._stepping; i++) {
          this._gameLoop();
        }
        this._telemetry.stepsRan(steps);
        const { droppedSteps, stallCount } = this._clock.drainStalls();
        this._telemetry.stalled(droppedSteps, stallCount);
      } else {
        for (let i = 0; i < steps; i++) this._idleStep();
      }

      if (!this.isHost) this._sendInputState();
    }

    const interpolating = this._interpolator.apply(this.gameState || {}, now);

    if (this._renderPending || interpolating) {
      this._renderPending = false;
      this._renderState();
      this._telemetry.frameRendered();
    }

    this._telemetry.bufferedObserved(this.transport.bufferedAmount || 0);
    this._telemetry.maybeFlush(now, this._transportTelemetryState());
  }

  /**
   * Apply an authoritative snapshot on the guest.
   *
   * The values on screen are captured first, then the snapshot lands in full,
   * then the keys this game declared as motion are walked back toward where
   * they were and re-approached over the next few frames. Scores, phases and
   * flags are never interpolated — there is no meaningful value between two of
   * them.
   *
   * @param {object} decoded
   * @param {() => void} [apply] - Game-specific application, when a plain merge
   *   would lose derived fields or event-driven audio.
   * @returns {void}
   */
  _ingestSnapshot(decoded, apply) {
    if (!decoded) return;

    const captured = this._interpolator.capture(this.gameState || {});

    if (apply) {
      apply();
    } else {
      this.gameState = { ...this.gameState, ...decoded };
    }

    this._interpolator.ingest(captured, this.gameState, this._now());
    this._invalidate();
  }

  // ── Channel I/O ──

  /**
   * @param {MessageEvent} event
   * @returns {void}
   */
  _onChannelMessage(event) {
    if (!(event.data instanceof ArrayBuffer) || event.data.byteLength < 1) return;

    const type = new DataView(event.data).getUint8(0);

    if (type === BASE_MSG.INPUT_STATE) {
      this._receiveInputState(event.data);
      return;
    }

    if (type === BASE_MSG.INPUT_EDGE) {
      this._receiveInputEdge(event.data);
      return;
    }

    // Anything at all from the host proves it heard the ready announcement.
    this._clearReadyHandshake();

    this._telemetry.stateReceived(event.data.byteLength, this._now());
    this._handleMessage(event);
  }

  /**
   * Send an authoritative snapshot, yielding when the channel is already behind.
   * @param {ArrayBuffer} data
   * @returns {boolean} whether the snapshot went out
   */
  _sendState(data) {
    const buffered = this.transport.bufferedAmount || 0;

    if (buffered >= SEND_HIGH_WATER_BYTES) {
      // Queuing behind a backlog only adds latency the game never recovers
      // from, and this snapshot is superseded by the next one regardless.
      this._telemetry.sendDropped(buffered);
      return false;
    }

    if (!this._safeSend(data)) return false;

    this._telemetry.stateSent(data.byteLength);
    return true;
  }

  /**
   * Send a one-shot control message. The game channel is unreliable, so this
   * repeats — a lost "the match is over" has no later message restating it.
   * @param {ArrayBuffer} data
   * @param {number} [repeats]
   * @returns {void}
   */
  _sendCommand(data, repeats = COMMAND_REPEATS) {
    this._safeSend(data);

    for (let attempt = 1; attempt < repeats; attempt++) {
      const timer = setTimeout(() => {
        this._commandTimers.delete(timer);
        if (this.running) this._safeSend(data);
      }, attempt * COMMAND_REPEAT_MS);

      this._commandTimers.add(timer);
    }
  }

  /**
   * Write to the DataChannel, tolerating a channel that closes mid-send.
   * @param {ArrayBuffer} data
   * @returns {boolean} whether the write was accepted
   */
  _safeSend(data) {
    if (this.transport.readyState !== "open") return false;

    try {
      this.transport.send(data);
      return true;
    } catch (error) {
      // Closed between the readyState check and the send — expected during
      // teardown, so debug (not warn) to avoid per-frame noise.
      log.debug("[GameEngine] DataChannel send failed", error);
      return false;
    }
  }

  // ── Input transport ──

  /** @returns {Record<string, number>} */
  get _inputBits() {
    return this.constructor.INPUT_BITS || {};
  }

  /**
   * Restate the guest's full input mask. Level-triggered by design: losing one
   * datagram costs a step of staleness, never a stuck key.
   *
   * A held mask is restated every frame. An empty mask is restated only for a
   * short run after the release — long enough that losing every copy is not a
   * realistic way to leave a key stuck down, short enough that an idle guest
   * stops talking.
   *
   * @returns {void}
   */
  _sendInputState() {
    const bits = this._inputBits;
    if (this.isHost || !Object.keys(bits).length) return;

    const mask = packInputs(this.localInputs, bits);
    const changed = mask !== this._lastSentMask;

    if (changed) {
      this._lastSentMask = mask;
      this._idleRestatesLeft = IDLE_INPUT_RESTATES;
    } else if (mask === 0) {
      // Nothing is held and the release has already been restated enough
      // times. A key that maps to nothing in this game changes no bit, so it
      // must not put a datagram on the wire either.
      if (this._idleRestatesLeft <= 0) return;
      this._idleRestatesLeft -= 1;
    }

    this._inputSeq = (this._inputSeq + 1) & 0xffff;
    this._safeSend(encodeInputState(this._inputSeq, mask));
  }

  // ── Ready handshake ──

  /**
   * Announce the guest as ready, and keep announcing until the host answers.
   *
   * This is the one message the whole match waits on: the host does nothing
   * until it arrives, and no later message restates it. On an unreliable
   * channel a single send would mean one dropped datagram hangs the game on
   * its waiting screen forever, which is a failure local testing over loopback
   * would never reproduce.
   *
   * @param {() => ArrayBuffer} encode - The game's ready-message encoder.
   * @returns {void}
   */
  _advertiseReady(encode) {
    if (this.isHost) return;

    this._readyEncoder = encode;
    this._safeSend(encode());

    this._readyTimer = setInterval(() => {
      if (!this.running) return this._clearReadyHandshake();
      this._safeSend(this._readyEncoder());
    }, READY_RETRY_MS);
  }

  /**
   * Stop announcing. Any message from the host proves it heard.
   * @returns {void}
   */
  _clearReadyHandshake() {
    if (this._readyTimer) {
      clearInterval(this._readyTimer);
      this._readyTimer = null;
    }
  }

  /**
   * Send a discrete command, repeated so an unreliable channel cannot swallow
   * it. The host deduplicates on the sequence number.
   * @param {number} code
   * @returns {void}
   */
  _sendInputEdge(code) {
    if (this.isHost) return;
    this._inputSeq = (this._inputSeq + 1) & 0xffff;
    this._sendCommand(encodeInputEdge(this._inputSeq, code));
  }

  /**
   * @param {ArrayBuffer} buf
   * @returns {void}
   */
  _receiveInputState(buf) {
    if (!this.isHost) return;

    const decoded = decodeInputState(buf);
    if (!decoded || !isNewerSeq(decoded.seq, this._lastRemoteInputSeq)) return;

    this._lastRemoteInputSeq = decoded.seq;

    // Some mechanics fire on the *edge*, not the level — releasing a key to
    // launch a held ball, for instance. A level-triggered transport hides that
    // unless the transition is reported, so the previous mask is kept and
    // handed over whenever it changes.
    const previous = { ...this.remoteInputs };
    unpackInputs(decoded.mask, this._inputBits, this.remoteInputs);

    for (const name of Object.keys(this._inputBits)) {
      if (previous[name] !== this.remoteInputs[name]) {
        this._onRemoteInputChange(previous, this.remoteInputs);
        return;
      }
    }
  }

  /**
   * @param {ArrayBuffer} buf
   * @returns {void}
   */
  _receiveInputEdge(buf) {
    if (!this.isHost) return;

    const decoded = decodeInputEdge(buf);
    if (!decoded || !isNewerSeq(decoded.seq, this._lastRemoteEdgeSeq)) return;

    this._lastRemoteEdgeSeq = decoded.seq;
    this._handleRemoteEdge(decoded.code);
  }

  // ── Keyboard ──

  /**
   * @param {KeyboardEvent} event
   * @returns {void}
   */
  _onKeyDown(event) {
    if (this._isTextEntry(event.target)) return;

    const captureKeyboard = this._shouldCaptureKeyboardEvent(event);

    // Auto-repeat restates a key that is already held: the game learns nothing
    // and the channel carries it anyway.
    if (event.repeat) {
      if (captureKeyboard) this._consumeCapturedKeyboardEvent(event);
      return;
    }

    const alreadyPrevented = event.defaultPrevented;
    this._handleKeyDown(event);

    if (captureKeyboard) {
      this._consumeCapturedKeyboardEvent(event);
    } else {
      this._stopHandledGameKey(event, alreadyPrevented);
    }

    this._sendInputState(true);
  }

  /**
   * @param {KeyboardEvent} event
   * @returns {void}
   */
  _onKeyUp(event) {
    if (this._isTextEntry(event.target)) return;

    const captureKeyboard = this._shouldCaptureKeyboardEvent(event);
    const alreadyPrevented = event.defaultPrevented;
    this._handleKeyUp(event);

    if (captureKeyboard) {
      this._consumeCapturedKeyboardEvent(event);
    } else {
      this._stopHandledGameKey(event, alreadyPrevented);
    }

    this._sendInputState(true);
  }

  /**
   * Game key handlers call preventDefault only after they recognize a key as
   * their own. Once that happens, the same keyboard event must not keep
   * bubbling to LiveView's global shortcut listener.
   * @param {KeyboardEvent} event
   * @param {boolean} alreadyPrevented
   * @returns {void}
   */
  _stopHandledGameKey(event, alreadyPrevented) {
    if (alreadyPrevented || !event.defaultPrevented) return;

    event.stopImmediatePropagation?.();
    event.stopPropagation?.();
  }

  /**
   * While a match owns the keyboard, the browser event must not reach
   * LiveView's window-level shortcuts. The game still receives it because this
   * listener runs in window capture before LiveView's bubble listener.
   * @param {KeyboardEvent} event
   * @returns {void}
   */
  _consumeCapturedKeyboardEvent(event) {
    if (event.defaultPrevented || this._shouldPreventDefaultForCapturedKey(event)) {
      event.preventDefault?.();
    }

    event.stopImmediatePropagation?.();
    event.stopPropagation?.();
  }

  /**
   * @param {boolean} captured
   * @returns {void}
   */
  setKeyboardCaptured(captured) {
    this._keyboardCaptured = captured === true;
  }

  /**
   * @param {KeyboardEvent} _event
   * @returns {boolean}
   */
  _shouldCaptureKeyboardEvent(_event) {
    return this._keyboardCaptured;
  }

  /**
   * @param {KeyboardEvent} _event
   * @returns {boolean}
   */
  _shouldPreventDefaultForCapturedKey(_event) {
    return false;
  }

  /**
   * Keystrokes aimed at a text field belong to the user. The game runs in a
   * window beside a chat composer, so this is the common case, not the edge.
   * @param {EventTarget|null} target
   * @returns {boolean}
   */
  _isTextEntry(target) {
    if (!target) return false;
    if (target.isContentEditable === true) return true;
    return TEXT_ENTRY_TAGS.has(target.tagName);
  }

  // ── Subclass hooks ──

  /**
   * Handle this game's own binary protocol. Base-protocol messages never reach
   * here.
   * @param {MessageEvent} _event
   * @returns {void}
   */
  _handleMessage(_event) {}

  /**
   * Run exactly one simulation step. Never schedules the next one.
   * @returns {void}
   */
  _gameLoop() {}

  /**
   * Run one step of presentation-only work while the simulation is stopped —
   * particles settling through a round-over pause, and nothing that changes the
   * outcome. Runs on the same fixed clock as `_gameLoop`, so a pause animates
   * at the same rate on every machine.
   * @returns {void}
   */
  _idleStep() {}

  /**
   * @param {KeyboardEvent} _event
   * @returns {void}
   */
  _handleKeyDown(_event) {}

  /**
   * @param {KeyboardEvent} _event
   * @returns {void}
   */
  _handleKeyUp(_event) {}

  /**
   * Apply a deduplicated discrete command from the guest. Only games with
   * command-style input override this.
   * @param {number} _code
   * @returns {void}
   */
  _handleRemoteEdge(_code) {}

  /**
   * React to the guest's held input changing. Only games with a mechanic that
   * fires on press or release — rather than on the key being down — override
   * this; holding is already visible in `remoteInputs`.
   * @param {Record<string, boolean>} _previous
   * @param {Record<string, boolean>} _current
   * @returns {void}
   */
  _onRemoteInputChange(_previous, _current) {}

  /**
   * Draw the current state. Driven by the presentation loop.
   * @returns {void}
   */
  _renderState() {
    this._render();
  }

  /**
   * @returns {number} monotonic milliseconds
   */
  _now() {
    return performance.now();
  }

  /**
   * @returns {string}
   */
  _transportTelemetryState() {
    return this.transport.telemetryState || this.transport.readyState || "unknown";
  }

  _renderStub() {
    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;

    // Use CSS custom properties via getComputedStyle for colors
    const styles = getComputedStyle(this.canvas);
    const bgColor = styles.getPropertyValue("--game-bg-color").trim() || gameColor("000033");
    const fgColor = styles.getPropertyValue("--game-fg-color").trim() || gameColor("00ff00");
    const mutedColor = styles.getPropertyValue("--game-muted-color").trim() || gameColor("006600");

    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, w, h);

    ctx.fillStyle = fgColor;
    ctx.font = "24px monospace";
    ctx.textAlign = "center";
    const title = this.gameId.replace(/_/g, " ").toUpperCase();
    ctx.fillText(title, w / 2, h / 2 - 30);

    ctx.font = "14px monospace";
    ctx.fillStyle = mutedColor;
    ctx.fillText(t("Game implementation coming soon!"), w / 2, h / 2 + 10);
    ctx.fillText(jt`Role: ${this.isHost ? "HOST" : "PEER"}`, w / 2, h / 2 + 40);

    // Draw decorative border
    ctx.strokeStyle = fgColor;
    ctx.lineWidth = 2;
    ctx.strokeRect(4, 4, w - 8, h - 8);
  }

  _render() {
    // Stub: will be overridden by specific game implementations
    this._renderStub();
  }
}
