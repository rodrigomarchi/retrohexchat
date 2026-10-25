import { vi } from "vitest";
import { createGameEngine } from "../../../js/lib/games/engine_loader.js";
import { createLocalTransport } from "../../../js/lib/games/transport.js";
import { channelPair } from "./channel_pair.js";
import { digest } from "./digest.js";
import { recordingAudio } from "./recording_audio.js";
import { recordingCanvas } from "./recording_canvas.js";
import { seedRandom } from "./seeded_random.js";

/**
 * Plays a match the way the browser does, and records what can be seen of it
 * from outside: the bytes on the channel, the phases, the sounds, a frame
 * painted in each phase and the result each side reports.
 *
 * Engines are built by `createGameEngine`, the factory the hooks use, so a
 * recording survives any change behind it. The test clock drives everything —
 * animation frames (every 16 ms), timers, `performance.now()`, `Date.now()` and
 * the audio clock — and `Math.random` follows the seed, so the same arguments
 * always give the same match.
 *
 * The only things read from inside an engine are listed in `observe` below:
 * the phase, the state's scalar fields and the AudioContext a side opened.
 *
 * @param {object} options
 * @param {string} options.gameId
 * @param {"p2p"|"solo"} [options.mode]
 * @param {number} [options.seed]
 * @param {number} [options.matchSeed] - the match's own seed (`options.seed` of
 *   the engines), apart from the page's `Math.random`
 * @param {string} [options.difficulty] - solo
 * @param {(data: ArrayBuffer, dir: string) => boolean} [options.drop]
 * @param {Array<{at: number, side: "host"|"guest", key: string, down: boolean}>} [options.script]
 * @param {number} [options.width]
 * @param {number} [options.height]
 * @param {Function} [options.EngineClass] - build engines from this class
 *   instead of the loader (for the core's own tests, with a test game)
 */
export async function playMatch({
  EngineClass = null,
  gameId,
  mode = "p2p",
  seed = 1,
  matchSeed,
  difficulty = "normal",
  drop,
  script = [],
  width = 640,
  height = 480,
}) {
  vi.useFakeTimers({
    now: 0,
    toFake: [
      "setTimeout",
      "clearTimeout",
      "setInterval",
      "clearInterval",
      "Date",
      "performance",
      "requestAnimationFrame",
      "cancelAnimationFrame",
    ],
  });
  seedRandom(seed);
  const audio = recordingAudio();
  // The page under test loads no stylesheet, so every custom property reads as
  // empty and each game falls back to its built-in palette. jsdom computes that
  // empty answer slowly, and some renderers ask dozens of times a frame.
  vi.stubGlobal("getComputedStyle", () => ({ getPropertyValue: () => "" }));

  const seeded = matchSeed === undefined ? {} : { seed: matchSeed };
  const results = { host: [], guest: [] };
  const keyboards = { host: new EventTarget(), guest: new EventTarget() };
  const canvases = { host: recordingCanvas(width, height) };
  const engines = {};
  let pair = null;

  const build = EngineClass
    ? async ({ canvas, mode: runtimeMode, channel, isHost, onGameEnd, engineOptions }) => {
        const solo = runtimeMode === "solo";
        const transport = solo ? createLocalTransport() : channel;
        const options = {
          ...engineOptions,
          mode: runtimeMode || (isHost ? "p2p_host" : "p2p_guest"),
        };
        if (solo) options.difficulty = difficulty;
        return new EngineClass(canvas, transport, gameId, solo ? true : isHost, onGameEnd, options);
      }
    : createGameEngine;

  if (mode === "solo") {
    engines.host = await build({
      canvas: canvases.host,
      gameId,
      mode: "solo",
      isHost: true,
      difficulty,
      onGameEnd: (result) => results.host.push(result),
      engineOptions: { keyboardTarget: keyboards.host, ...seeded },
    });
  } else {
    pair = channelPair({ drop });
    canvases.guest = recordingCanvas(width, height);
    for (const side of ["host", "guest"]) {
      engines[side] = await build({
        canvas: canvases[side],
        gameId,
        channel: pair[side],
        isHost: side === "host",
        onGameEnd: (result) => results[side].push(result),
        engineOptions: { keyboardTarget: keyboards[side], ...seeded },
      });
    }
  }

  const sides = Object.keys(engines);
  const phases = [];
  const draws = [];
  const lastPhase = {};
  let observerFrame = null;

  const capturing = {};
  for (const canvas of Object.values(canvases)) canvas.recording = false;

  // Runs once per animation frame, after the engines have painted it. A phase
  // change switches that side's canvas recording on until the next frame that
  // is actually painted (an engine repaints only when something changed), and
  // that frame is the one kept: recording every frame would cost more than the
  // game itself.
  const observeFrame = () => {
    observerFrame = requestAnimationFrame(observeFrame);
    for (const side of sides) {
      const phase = observe.phase(engines[side]);
      const canvas = canvases[side];

      if (capturing[side] !== undefined && canvas.log.length > 0) {
        draws.push({
          t: Date.now(),
          side,
          phase: capturing[side],
          ops: canvas.log.length,
          digest: digest(canvas.log),
        });
        capturing[side] = undefined;
        canvas.recording = false;
      }

      if (phase !== lastPhase[side]) {
        lastPhase[side] = phase;
        phases.push({ t: Date.now(), side, phase });
        capturing[side] = phase;
        canvas.clearLog();
        canvas.recording = true;
      }
    }
  };

  for (const side of sides) engines[side].start();
  if (mode === "solo") engines.host.beginMatch({ difficulty });
  observerFrame = requestAnimationFrame(observeFrame);

  const scriptTimers = script.map(({ at, side, key, down }) =>
    setTimeout(() => {
      keyboards[side].dispatchEvent(
        new KeyboardEvent(down ? "keydown" : "keyup", { key, cancelable: true }),
      );
    }, at),
  );

  let stopped = false;

  return {
    engines,
    results,

    /** Move the test clock forward, running every frame and timer due. */
    advance(ms) {
      vi.advanceTimersByTime(ms);
    },

    /**
     * Advance in 1 s slices until `done()` holds or `limit` ms have passed.
     * @returns {boolean} whether `done()` held
     */
    runUntil(done, limit) {
      const deadline = Date.now() + limit;
      while (!done() && Date.now() < deadline) vi.advanceTimersByTime(1000);
      return done();
    },

    /**
     * Whether the match is over: a result reported, or the host in the phase
     * the match ends in (a game can reach it without reporting anything).
     */
    over() {
      return results.host.length > 0 || observe.finished(engines.host);
    },

    /** Dispatch one key event on a side's keyboard and hand it back. */
    key(side, key, type = "keydown") {
      const event = new KeyboardEvent(type, { key, cancelable: true });
      keyboards[side].dispatchEvent(event);
      return event;
    },

    /** The channel drops, on both ends. */
    close() {
      pair?.close();
    },

    record() {
      return {
        wire: pair ? pair.wire.slice() : [],
        phases: phases.slice(),
        draws: draws.slice(),
        sounds: Object.fromEntries(
          sides.map((side) => [side, audio.entriesOf(observe.audioContext(engines[side]))]),
        ),
        state: Object.fromEntries(sides.map((side) => [side, observe.state(engines[side])])),
        results: { host: results.host.slice(), guest: results.guest.slice() },
      };
    },

    /** Timers still scheduled; after `stop()` this is what an engine leaked. */
    pendingTimers() {
      return vi.getTimerCount();
    },

    stop() {
      if (stopped) return;
      stopped = true;
      cancelAnimationFrame(observerFrame);
      for (const timer of scriptTimers) clearTimeout(timer);
      for (const side of sides) engines[side].stop();
      this.leaked = vi.getTimerCount();
    },

    /** Put the real clock and `Math.random` back. Call after `stop()`. */
    restore() {
      vi.useRealTimers();
      vi.restoreAllMocks();
      vi.unstubAllGlobals();
    },
  };
}

/**
 * Everything the harness reads from inside an engine. When the engines change
 * shape, this is the one place that follows.
 */
export const observe = {
  phase: (engine) => engine.gameState?.phase ?? null,

  /** Whether the match has reached the phase it ends in. */
  finished: (engine) =>
    engine.constructor.FINAL_PHASE !== null &&
    engine.gameState?.phase === engine.constructor.FINAL_PHASE,

  /** The state's scalar fields — scores, phase, round, lives — sorted by name. */
  state(engine) {
    const state = engine.gameState ?? {};
    return Object.fromEntries(
      Object.keys(state)
        .sort()
        .filter((key) => ["number", "string", "boolean"].includes(typeof state[key]))
        .map((key) => [key, state[key]]),
    );
  },

  audioContext: (engine) => engine.audio?.ctx ?? null,
};
