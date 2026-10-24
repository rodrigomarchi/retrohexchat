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
 *   audio: PongAudio,
 *   theme: getColors,
 *   init: (game, options) => createInitialState(),
 *   flow: { phases: PHASE, initial: "WAITING", begin: "COUNTDOWN", states: { … } },
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
 * The phase hooks in `flow.states` receive the game and use its public
 * surface: `gameState`, `localInputs`, `remoteInputs`, `audio`, `broadcast()`,
 * `invalidate()`, `updateOpponent()`, `finish()` and `flow.go()`.
 *
 * The class is still a `GameEngine` underneath, with the constructor
 * `createGameEngine` calls, so the hooks and the loader do not change.
 *
 * @module games/core/define_game
 */

import { GameEngine, keymap } from "../../game_engine.js";
import { encodeGameReady } from "../net_protocol.js";
import { createFlow } from "./flow.js";
import { MSG, dispatcher } from "./messages.js";

const REQUIRED = ["inputs", "schema", "init", "flow", "render", "disconnectResult"];

/**
 * @param {object} def
 * @returns {typeof GameEngine}
 */
export function defineGame(def) {
  validate(def);

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
      this.onGameEnd = onGameEnd || null;
      this.gameState = def.init(this, options);
      this.localInputs = released();
      this.remoteInputs = released();
      if (def.ai) {
        this.difficulty = def.ai.difficulty(options.difficulty);
        this.opponentController =
          options.opponentController ||
          (this.mode === "solo" && def.ai.create
            ? def.ai.create({ difficulty: this.difficulty })
            : null);
      }
      this.frameCount = 0;
      this.audio = def.audio ? new def.audio() : null;
      this.colors = null;
      this.peerReady = false;
      def.setup?.(this, options);

      this.flow = createFlow(def.flow, {
        // A game may have no state yet (it is built on start).
        readPhase: () => this.gameState?.phase,
        writePhase: (value) => {
          this.gameState.phase = value;
        },
        startSteps: () => this._startSteps(),
        stopSteps: () => this._stopSteps(),
        target: this,
      });

      this._dispatch = dispatcher({
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
          this.opponentController = def.ai.create({ difficulty: this.difficulty });
        }
      }

      this.setKeyboardCaptured(true);
      this.peerReady = true;
      this.flow.go(def.flow.begin);
      return true;
    }

    // ── What the phase hooks use ──

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
      this._sendCommand(def.schema.end.encode(end));
      if (broadcast) this._broadcastState();
      this._reportResult(result);
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
      this.setKeyboardCaptured(decoded.phase !== waiting && decoded.phase !== final);
      def.onSnapshot?.(this, decoded, previous);
    }

    _gameLoop() {
      if (!this.running) return;
      this.flow.step();
    }

    _idleStep() {
      def.idle?.(this);
    }

    _clearPhaseTimer() {
      this.flow?.stop();
      super._clearPhaseTimer();
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
      if (!this.gameState) return;
      const wire = def.toWire ? def.toWire(this) : this.gameState;
      this._sendState(def.schema.snapshot.encode(wire));
    }

    _renderState() {
      def.render(this);
    }

    _shouldPreventDefaultForCapturedKey(event) {
      return captureKeys.has(event.key);
    }

    _disconnectResult() {
      return def.disconnectResult(this);
    }
  };
}

function validate(def) {
  for (const field of REQUIRED) {
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
