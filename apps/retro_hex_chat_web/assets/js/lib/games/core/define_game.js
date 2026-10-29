/**
 * A game from its definition.
 *
 * Every game used to repeat the same match lifecycle — start, the ready
 * handshake, beginning against the AI, dispatching messages, the countdown,
 * the end and the disconnect — with small differences, some of them bugs. A
 * definition says only what is the game's own; this module supplies the rest.
 *
 * ```js
 * export default defineGame({
 *   inputs: { up: ["ArrowUp", "w"], down: ["ArrowDown", "s"] },   // order = bit order
 *   captureKeys: ["ArrowUp", "ArrowDown", " "],
 *   interpolate: { keys: ["ballX", "ballY"] },
 *   schema: { snapshot: SNAPSHOT, end: GAME_END },
 *   ai: { create: createPongAI, difficulty: normalizePongAIDifficulty }, // no create: the page hands it in
 *   audio: { sounds: SOUNDS },                     // played by name: playPaddleHit()
 *   theme: getColors,
 *   setup: (game, options) => …,                  // once, in the constructor, before the flow exists
 *   init: (game, options) => createInitialState(),
 *   flow: { phases: PHASE, initial: "WAITING", begin: "COUNTDOWN", states: { … } },
 *   cues: [{ phase: PHASE.COUNTDOWN, play: "countdown" }, …], // what the guest hears (core/events.js)
 *   idle: (game) => …,                             // each frame while no match runs (the flow's idle step)
 *   toWire: (game) => wireState,                   // host: what the snapshot encodes, when not gameState itself
 *   applySnapshot: (game, decoded) => …,          // guest: lands a snapshot in place of the default copy
 *   onSnapshot: (game, decoded, previous) => …,   // guest, after a snapshot lands
 *   onEnd: (game, result) => …,                    // guest, when the host ends the match
 *   onStart, onStop: (game) => …,                  // around the engine's own start and stop
 *   onRemoteInputChange: (game, previous, current) => …,  // the guest's or AI's held inputs changed
 *   onKeyDown, onKeyUp: (game, event) => …,        // after the engine's own key handling
 *   onBlur: (game) => …,                            // on losing focus, before inputs are released
 *   onRemoteEdge: (game, code) => …,                // a discrete command from the guest
 *   onAbandon: (game) => …,                         // the channel dropped mid-match: silence what runs
 *   render: (game) => …,
 *   disconnectResult: (game) => ({ … }),
 * });
 * ```
 *
 * A game for one player says `players: 1` and `standing: (game) => result`,
 * the result as the score stands (`soloResult` from `core/result.js`). It
 * plays solo only, never goes on the wire and has no opponent, so it declares
 * no `schema`, `ai`, `disconnectResult`, `cues` or snapshot hooks; its
 * `broadcast()` does nothing and its `finish({ result })` only tells the page.
 *
 * A game played with a mouse or a finger says `pointer: true` and
 * `onPointer: (game, event) => …`. The engine reads the canvas's pointer
 * events and hands them over at the start of the next tick, in the order they
 * happened — while the match runs and while it waits — so a seed and a script
 * of presses replay the same match. `event` is `{ type, x, y }`: `type` is
 * `"down"`, `"move"`, `"up"` or `"cancel"` (the browser took the press away,
 * or the window lost focus, which carries no point), and `x`, `y` are the
 * canvas's pixels (`core/pointer.js`). One press is followed at a time — a
 * second finger is ignored — and a press off the picture starts nothing.
 * A game that also reads a right click says `pointerButtons: ["main",
 * "secondary"]`: every event of a press then carries `button` ("main" or
 * "secondary") and `device` ("mouse", "touch" or "pen", when the browser
 * says), and the browser's menu stays shut over the canvas.
 * The canvas of a pointer game takes the touch for itself
 * (`game-canvas--pointer`), so a drag on a phone moves a card, not the page.
 *
 * `view: (canvas, gameId) => ({ width, height }) | null` lets a game choose the picture
 * it draws from the box the page gave its canvas — a table standing up on a
 * phone held upright; null keeps the size the page gave.
 *
 * `resolution: 2` gives the canvas twice the pixels each way while the game
 * goes on drawing and reading presses at the size the page gave it
 * (`game.view`); every frame begins scaled. `pixelArt: true` draws unsmoothed
 * and keeps the browser from smoothing the canvas when it stretches it
 * (`game-canvas--pixel-art`), so pixel art stays crisp.
 *
 * `quit()` ends a solo match early, as it stands: the page is told the score
 * (`standing`, or for a two-player game the score `disconnectResult` reads)
 * with `ended_early: true` and nobody named the winner.
 *
 * The phase hooks in `flow.states` receive the game and use its public
 * surface: `gameState`, `localInputs`, `remoteInputs`, `audio`, `broadcast()`,
 * `invalidate()`, `updateOpponent()`, `finish()` and `flow.go()`; key hooks
 * also `keyInput(event)` (the input a key drives) and, for a game whose input
 * is a command, `sendInputEdge(code)`.
 *
 * The class is still a `GameEngine` underneath, with the constructor
 * `createGameEngine` calls, so the hooks and the loader do not change.
 *
 * @module games/core/define_game
 */

import { GameEngine, keymap } from "../../game_engine.js";
import { encodeGameReady } from "../net_protocol.js";
import { cueSounds } from "./events.js";
import { createFlow } from "./flow.js";
import { aiRandom, createRng, freshSeed } from "./rng.js";
import { toCanvasPoint } from "./pointer.js";
import { createGameAudio } from "./synth.js";
import { MSG, dispatcher } from "./messages.js";
import { log } from "../../logger.js";

const REQUIRED = ["inputs", "schema", "init", "flow", "render", "disconnectResult"];
const ONE_PLAYER_REQUIRED = ["inputs", "init", "flow", "render", "standing"];

/** The canvas's pointer events, by the name a game is handed. */
/** A mouse button's number, as the game is told it. */
const BUTTONS = Object.freeze({ 0: "main", 2: "secondary" });

const POINTER_EVENTS = Object.freeze({
  pointerdown: "down",
  pointermove: "move",
  pointerup: "up",
  pointercancel: "cancel",
});

/**
 * The keys of each direction: its arrow, and its WASD letter in either case.
 * A game's `inputs` name what each direction does, e.g. `{ fire: [" "],
 * rotateLeft: ARROW_KEYS.left }`.
 */
export const ARROW_KEYS = Object.freeze({
  up: Object.freeze(["ArrowUp", "w", "W"]),
  down: Object.freeze(["ArrowDown", "s", "S"]),
  left: Object.freeze(["ArrowLeft", "a", "A"]),
  right: Object.freeze(["ArrowRight", "d", "D"]),
});

/**
 * The arrows, WASD in either case and the space bar: the keys most games take
 * from the page while a match runs, so they move and fire instead of scrolling.
 */
export const ARROWS_WASD_SPACE = Object.freeze([
  "ArrowUp",
  "ArrowDown",
  "ArrowLeft",
  "ArrowRight",
  " ",
  "Spacebar",
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
 * A seed for the world the host makes, drawn from the match's own generator.
 * @param {{ random: () => number }} game
 * @returns {number} a 32-bit unsigned integer
 */
export function drawSeed(game) {
  return (game.random() * 0xffffffff) >>> 0;
}

/**
 * The `init` of a game whose id picks its mode and whose host seeds its
 * world: `game.gameMode` from `modes` by the game id (else `fallback`), and
 * `game.seed` drawn by the host — the guest's is 0 until a snapshot brings
 * the host's. The state is `create(mode, seed)`.
 * @param {Record<string, number>} modes - game id to mode
 * @param {number} fallback
 * @param {(mode: number, seed: number) => object} create
 * @returns {(game: object) => object}
 */
export function seededInit(modes, fallback, create) {
  return (game) => {
    game.gameMode = modes[game.gameId] ?? fallback;
    game.seed = game.isHost ? drawSeed(game) : 0;
    return create(game.gameMode, game.seed);
  };
}

/**
 * The snapshot of a game whose state goes on the wire packed flat: the host
 * sends `pack(state)`; the guest takes the mode it names and `unpack`s it.
 * @param {(state: object) => object} pack
 * @param {(decoded: object) => object} unpack
 * @returns {{ toWire: Function, applySnapshot: Function }} for defineGame
 */
export function packedSnapshot(pack, unpack) {
  return {
    toWire: (game) => pack(game.gameState),
    applySnapshot: (game, decoded) => {
      game.gameMode = decoded.mode;
      game.gameState = unpack(decoded);
    },
  };
}

/**
 * The `onStart` of a seeded game: the host starts from a fresh state of its
 * mode and seed (`create(mode, seed)`), so a match begun again on the same
 * engine starts from the beginning.
 * @param {(mode: number, seed: number) => object} create
 * @returns {(game: object) => void}
 */
export function freshOnHost(create) {
  return (game) => {
    if (game.isHost) game.gameState = create(game.gameMode, game.seed);
  };
}

/**
 * @param {object} def
 * @returns {typeof GameEngine}
 */
export function defineGame(def) {
  validate(def);

  const onePlayer = def.players === 1;
  const pointer = def.pointer === true;
  // A game may take the secondary button too (a right click); the menu then stays shut.
  const secondary = pointer && (def.pointerButtons ?? ["main"]).includes("secondary");
  const resolution = def.resolution ?? 1;
  const scaled = resolution !== 1 || def.pixelArt === true;
  const inputNames = Object.keys(def.inputs);
  const inputBits = Object.fromEntries(inputNames.map((name, bit) => [name, bit]));
  const released = () => Object.fromEntries(inputNames.map((name) => [name, false]));
  const captureKeys = new Set(def.captureKeys ?? []);
  const { phases, states } = def.flow;
  const finalName = Object.keys(states).find((name) => states[name].final);
  const waiting = phases[def.flow.initial];
  const final = phases[finalName];

  return class extends GameEngine {
    static INPUT_BITS = inputBits;
    static KEYMAP = keymap(def.inputs);
    static INTERPOLATION = def.interpolate ?? { keys: [] };
    static FINAL_PHASE = final;

    constructor(canvas, channel, gameId, isHost, onGameEnd, options = {}) {
      super(canvas, channel, gameId, isHost, options);
      if (onePlayer && this.mode !== "solo") {
        throw new Error(`defineGame: ${gameId} is a one-player game; it plays solo only`);
      }
      this.onGameEnd = onGameEnd || null;
      // The picture the game draws, before its state is made from it. The
      // size the page gave the canvas is kept on it: the page builds every
      // engine of a match on the same canvas, which an earlier one has already
      // given more pixels.
      canvas.dataset.gameWidth ??= String(canvas.width);
      canvas.dataset.gameHeight ??= String(canvas.height);
      this.view = def.view?.(canvas, gameId) ?? {
        width: Number(canvas.dataset.gameWidth),
        height: Number(canvas.dataset.gameHeight),
      };
      if (resolution !== 1 || def.view) {
        canvas.width = this.view.width * resolution;
        canvas.height = this.view.height * resolution;
      }
      if (def.pixelArt) canvas.classList.add("game-canvas--pixel-art");
      if (pointer) canvas.classList.add("game-canvas--pointer");
      // One seed plays one match: the simulation draws from its generator,
      // decoration (particles) and the AI from streams forked off it, so
      // neither changes how a match plays out.
      this.matchSeed = options.seed ?? freshSeed();
      const rng = createRng(this.matchSeed);
      this.random = rng.next;
      this.fxRandom = createRng(this.matchSeed).fork("fx").next;
      this.gameState = def.init(this, options);
      this.localInputs = released();
      this.remoteInputs = released();
      if (def.ai) {
        this.difficulty = def.ai.difficulty(options.difficulty);
        this.opponentController =
          options.opponentController ||
          (this.mode === "solo" && def.ai.create
            ? def.ai.create({ difficulty: this.difficulty, rng: aiRandom(this.matchSeed) })
            : null);
      }
      this.frameCount = 0;
      this.audio = audioOf(def.audio);
      this.colors = null;
      this.peerReady = false;
      this._pointerQueue = [];
      this._activePointer = null;
      this._boundPointer = pointer ? this._onPointerEvent.bind(this) : null;
      def.setup?.(this, options);

      this.flow = createFlow(def.flow, {
        // A game may have no state yet (it is built on start).
        readPhase: () => this.gameState?.phase,
        writePhase: (value) => {
          this.gameState.phase = value;
        },
        startSteps: () => this._startSteps(),
        stopSteps: () => this._stopSteps(),
        idle: () => def.idle?.(this),
        target: this,
      });

      this._dispatch = onePlayer
        ? () => {}
        : dispatcher({
            [MSG.GAME_STATE]: (buf) => this._receiveSnapshot(buf),
            [MSG.GAME_READY]: () => {
              if (this.isHost && !this.peerReady) this.beginMatch();
            },
            // Only the host ends a match; one sent to the host is ignored.
            [MSG.GAME_END]: (buf) => {
              if (this.isHost) return;
              const result = def.schema.end.decode(buf);
              if (result) def.onEnd?.(this, result);
            },
          });
    }

    start() {
      if (this.running) return;
      super.start();
      if (pointer) {
        for (const type of Object.keys(POINTER_EVENTS)) {
          this.canvas.addEventListener(type, this._boundPointer);
        }
        if (secondary) this.canvas.addEventListener("contextmenu", this._preventMenu);
      }
      if (def.theme) this.colors = def.theme(this.canvas);
      def.onStart?.(this);

      if (this.mode === "solo") {
        this.peerReady = true;
      } else if (!this.isHost) {
        // The host engine may still be loading lazily, so readiness is
        // repeated until the host answers.
        this._advertiseReady(encodeGameReady);
      }
      this._invalidate();
    }

    stop() {
      def.onStop?.(this);
      if (pointer) {
        for (const type of Object.keys(POINTER_EVENTS)) {
          this.canvas.removeEventListener(type, this._boundPointer);
        }
        this.canvas.removeEventListener("contextmenu", this._preventMenu);
        this._pointerQueue = [];
        this._activePointer = null;
      }
      super.stop();
    }

    /**
     * Begin the match: only on the host, only while waiting.
     * @param {{ difficulty?: string, opponentController?: object }} [options]
     * @returns {boolean} whether it began
     */
    beginMatch(options = {}) {
      if (!this.running || !this.isHost || !this.gameState || this.gameState.phase !== waiting) {
        return false;
      }

      if (def.ai) {
        if (options.difficulty) {
          this.difficulty = def.ai.difficulty(options.difficulty);
          if (
            !options.opponentController &&
            typeof this.opponentController?.setDifficulty === "function"
          ) {
            this.opponentController.setDifficulty(this.difficulty);
          }
        }
        if (options.opponentController) this.opponentController = options.opponentController;
        if (this.mode === "solo" && !this.opponentController) {
          // A game that leaves creating its AI to the page cannot play solo without one.
          if (!def.ai.create) return false;
          this.opponentController = def.ai.create({
            difficulty: this.difficulty,
            rng: this.random,
          });
        }
      }

      this.setKeyboardCaptured(true);
      this.peerReady = true;
      this.flow.go(def.flow.begin);
      return true;
    }

    // ── What the phase hooks use ──

    /**
     * Let go of every input, this player's and the other's, forget the peer
     * and count frames from 0 again: what a game stopped between matches
     * does before the next.
     */
    forgetMatch() {
      this.localInputs = released();
      this.remoteInputs = released();
      this.peerReady = false;
      this.frameCount = 0;
    }

    /** Send the host's snapshot to the guest. */
    broadcast() {
      this._broadcastState();
    }

    /** Ask for a repaint on the next frame. */
    invalidate() {
      this._invalidate();
    }

    /**
     * How the match ended for the player at this screen: the host (and the
     * human in solo play) is player one, the guest player two.
     * @param {number} winner - 1, 2, or anything else for no winner
     * @returns {"win" | "lose" | "draw"}
     */
    outcome(winner) {
      if (winner !== 1 && winner !== 2) return "draw";
      return winner === (this.isHost ? 1 : 2) ? "win" : "lose";
    }

    /** In solo play, let the AI decide the guest's inputs for this step. */
    updateOpponent() {
      this._updateOpponentInputs();
    }

    /**
     * End the match on the host: stop, tell the guest (repeated, since the
     * channel is unreliable), send a last snapshot and report the result
     * (a callback that throws is logged, not let out).
     * @param {{ end: object, result: object, broadcast?: boolean }} outcome -
     *   `end` is what goes on the wire, `result` what the page is told;
     *   `broadcast: false` leaves out the last snapshot, for a game that sent
     *   it before the end
     */
    finish({ end, result, broadcast = true }) {
      this._stopSteps();
      this.setKeyboardCaptured(false);
      if (!onePlayer) {
        this._sendCommand(def.schema.end.encode(end));
        if (broadcast) this._broadcastState();
      }
      this._reportResult(result);
    }

    /**
     * End a solo match where it stands, reporting its score once.
     * @returns {boolean} whether a match was running to end
     */
    quit() {
      if (this.mode !== "solo" || !(this.stepping || this.paused) || !this.gameState) return false;
      if (this.gameState.phase === final) return false;
      const { score } = (def.standing ?? def.disconnectResult)(this);
      this._paused = false;
      this._stopSteps();
      this.setKeyboardCaptured(false);
      this._cancelPendingPhase();
      this.gameState.phase = final;
      this._onMatchAbandoned();
      this._invalidate();
      this._reportResult({ score, ended_early: true });
      return true;
    }

    /**
     * Hold a solo match: a press still down is let go (cancelled), and none
     * is taken while it is held.
     * @returns {boolean} whether it paused
     */
    pause() {
      if (!super.pause()) return false;
      // The press let go by the pause (its cancel) is kept for the resume.
      this._pointerQueue = this._pointerQueue.filter((event) => event.type === "cancel");
      this._activePointer = null;
      return true;
    }

    // ── GameEngine hooks ──

    _handleMessage(event) {
      this._dispatch(event.data);
    }

    _receiveSnapshot(buf) {
      if (this.isHost) return;
      const decoded = def.schema.snapshot.decode(buf);
      if (!decoded) return;

      const previous = { ...this.gameState };
      this._ingestSnapshot(
        decoded,
        def.applySnapshot ? () => def.applySnapshot(this, decoded) : undefined,
      );
      if (def.cues) cueSounds(def.cues, previous, this.gameState, this);
      this.setKeyboardCaptured(decoded.phase !== waiting && decoded.phase !== final);
      def.onSnapshot?.(this, decoded, previous);
    }

    _gameLoop() {
      this._deliverPointer();
      this.flow.step();
      this._watchPhase();
    }

    // Every phase change is the end of one round, serve or match and the
    // start of the next: the AI forgets what it kept of the last one. The
    // engine watches the phase itself, every step, so an AI asked only while
    // a round is played hears of it as surely as one asked every step.
    _watchPhase() {
      const phase = this.gameState?.phase;
      if (phase === this._watchedPhase) return;
      this._watchedPhase = phase;
      this.opponentController?.forget?.();
    }

    _idleStep() {
      this._deliverPointer();
      def.idle?.(this);
    }

    // The pointer events since the last tick, handed over in order.
    _deliverPointer() {
      if (!pointer || this._pointerQueue.length === 0) return;
      const events = this._pointerQueue;
      this._pointerQueue = [];
      for (const event of events) def.onPointer(this, event);
    }

    _onPointerEvent(event) {
      const type = POINTER_EVENTS[event.type];
      const id = event.pointerId ?? 0;
      if (type === "down") {
        // The main button, a finger or a pen; the secondary one only for a
        // game that asks for it. A middle click is never a press.
        const button = BUTTONS[event.button ?? 0];
        if (this._activePointer !== null || !button || (button === "secondary" && !secondary)) {
          return;
        }
        const point = this._pointAt(event, true);
        if (!point) return;
        this._activePointer = id;
        this._activeButton = secondary ? button : undefined;
        this._activeDevice = event.pointerType || undefined;
        this._capturePointer(id);
        this._pointerQueue.push(this._withButton({ type, ...point }));
        return;
      }
      if (id !== this._activePointer) return;
      if (type === "cancel") {
        this._activePointer = null;
        this._pointerQueue.push({ type });
        return;
      }
      const point = this._pointAt(event, false);
      if (point) this._pointerQueue.push(this._withButton({ type, ...point }));
      if (type === "up") this._activePointer = null;
    }

    // A two-button game is told which button each event of a press belongs to,
    // and what made it ("mouse", "touch" or "pen"), when the browser says.
    _withButton(event) {
      if (this._activeButton === undefined) return event;
      const device = this._activeDevice === undefined ? {} : { device: this._activeDevice };
      return { ...event, button: this._activeButton, ...device };
    }

    _preventMenu(event) {
      event.preventDefault();
    }

    _pointAt(event, clamp) {
      return toCanvasPoint(
        this.canvas.getBoundingClientRect(),
        this.view.width,
        this.view.height,
        event.clientX,
        event.clientY,
        { clamp },
      );
    }

    // A drag that leaves the canvas keeps reporting to it.
    _capturePointer(id) {
      if (typeof this.canvas.setPointerCapture !== "function") return;
      try {
        this.canvas.setPointerCapture(id);
      } catch (error) {
        log.debug("[defineGame] pointer capture refused", error);
      }
    }

    _cancelPendingPhase() {
      this.flow?.stop();
      super._cancelPendingPhase();
    }

    _updateOpponentInputs() {
      if (this.mode !== "solo" || typeof this.opponentController?.nextInputs !== "function") return;
      const observed = def.ai.observe
        ? def.ai.observe(this)
        : { state: this.gameState, difficulty: this.difficulty, player: 2 };
      const next = this.opponentController.nextInputs(observed);
      if (!next) return;
      const previous = this.remoteInputs;
      this.remoteInputs = Object.fromEntries(inputNames.map((name) => [name, next[name] === true]));
      // The AI's presses and releases reach the game the way the guest's do.
      if (inputNames.some((name) => previous[name] !== this.remoteInputs[name])) {
        this._onRemoteInputChange(previous, this.remoteInputs);
      }
    }

    _onRemoteInputChange(previous, current) {
      def.onRemoteInputChange?.(this, previous, current);
    }

    _onMatchAbandoned() {
      def.onAbandon?.(this);
    }

    _handleBlur() {
      def.onBlur?.(this);
      if (pointer && this._activePointer !== null) {
        this._activePointer = null;
        this._pointerQueue.push({ type: "cancel" });
      }
      super._handleBlur();
    }

    _handleKeyDown(event) {
      super._handleKeyDown(event);
      def.onKeyDown?.(this, event);
    }

    _handleKeyUp(event) {
      super._handleKeyUp(event);
      def.onKeyUp?.(this, event);
    }

    _handleRemoteEdge(code) {
      def.onRemoteEdge?.(this, code);
    }

    _broadcastState() {
      if (onePlayer || !this.gameState) return;
      const wire = def.toWire ? def.toWire(this) : this.gameState;
      this._sendState(def.schema.snapshot.encode(wire));
    }

    // Nothing is drawn before the theme is read: the engine can ask for a
    // frame while it starts, and no game draws without its colours.
    _renderState() {
      if (def.theme && !this.colors) return;
      if (scaled) {
        this.ctx.setTransform(resolution, 0, 0, resolution, 0, 0);
        if (def.pixelArt) this.ctx.imageSmoothingEnabled = false;
      }
      def.render(this);
    }

    _shouldPreventDefaultForCapturedKey(event) {
      return captureKeys.has(event.key);
    }

    // A one-player game has nobody to lose: a closed transport ends nothing.
    _disconnectResult() {
      return onePlayer ? null : def.disconnectResult(this);
    }

    _reportDisconnect(result) {
      if (result) super._reportDisconnect(result);
    }
  };
}

/** A game's sounds, played by the core's synthesizer. */
function audioOf(spec) {
  return spec ? createGameAudio(spec) : null;
}

function validate(def) {
  if (def.players !== undefined && def.players !== 1 && def.players !== 2) {
    throw new Error(`defineGame: players is 1 or 2, not ${def.players}`);
  }
  if (def.pointer === true && typeof def.onPointer !== "function") {
    throw new Error("defineGame: a pointer game needs onPointer");
  }
  if (def.resolution !== undefined && !(Number.isInteger(def.resolution) && def.resolution >= 1)) {
    throw new Error(`defineGame: resolution is a whole number from 1, not ${def.resolution}`);
  }
  if (def.players === 1 && def.ai) {
    throw new Error("defineGame: a one-player game has no opponent");
  }
  for (const field of def.players === 1 ? ONE_PLAYER_REQUIRED : REQUIRED) {
    if (def[field] === undefined) throw new Error(`defineGame: missing ${field}`);
  }
  const { phases, states, initial, begin } = def.flow;
  const known = (name) => name in phases || states[name]?.as in phases;
  for (const name of [initial, begin, ...Object.keys(states)]) {
    if (!known(name)) throw new Error(`defineGame: flow names ${name}, which is not a phase`);
  }
  for (const [name, state] of Object.entries(states)) {
    if (typeof state.next === "string" && !known(state.next)) {
      throw new Error(`defineGame: ${name} moves to ${state.next}, which is not a phase`);
    }
  }
  if (!Object.values(states).some((state) => state.final)) {
    throw new Error("defineGame: flow has no final phase");
  }
}
