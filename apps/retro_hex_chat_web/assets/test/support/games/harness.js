import { vi } from "vitest";
import { createGameEngine } from "../../../js/lib/games/engine_loader.js";
import { channelPair } from "./channel_pair.js";
import { digest } from "./digest.js";
import { recordingAudio } from "./recording_audio.js";
import { recordingCanvas } from "./recording_canvas.js";
import { seedRandom } from "./seeded_random.js";

/**
 * Plays a match the way the browser does, and records what can be seen of it
 * from outside: the bytes on the channel, the phases, the sounds, the frames
 * drawn and the result each side reports.
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
 * @param {string} [options.difficulty] - solo
 * @param {(data: ArrayBuffer, dir: string) => boolean} [options.drop]
 * @param {Array<{at: number, side: "host"|"guest", key: string, down: boolean}>} [options.script]
 * @param {number} [options.width]
 * @param {number} [options.height]
 */
export async function playMatch({
  gameId,
  mode = "p2p",
  seed = 1,
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

  const results = { host: [], guest: [] };
  const keyboards = { host: new EventTarget(), guest: new EventTarget() };
  const canvases = { host: recordingCanvas(width, height) };
  const engines = {};
  let pair = null;

  if (mode === "solo") {
    engines.host = await createGameEngine({
      canvas: canvases.host,
      gameId,
      mode: "solo",
      isHost: true,
      difficulty,
      onGameEnd: (result) => results.host.push(result),
      engineOptions: { keyboardTarget: keyboards.host },
    });
  } else {
    pair = channelPair({ drop });
    canvases.guest = recordingCanvas(width, height);
    for (const side of ["host", "guest"]) {
      engines[side] = await createGameEngine({
        canvas: canvases[side],
        gameId,
        channel: pair[side],
        isHost: side === "host",
        onGameEnd: (result) => results[side].push(result),
        engineOptions: { keyboardTarget: keyboards[side] },
      });
    }
  }

  const sides = Object.keys(engines);
  const phases = [];
  const draws = [];
  const lastPhase = {};
  let observerFrame = null;

  // Runs once per animation frame, after the engines have painted it.
  const observeFrame = () => {
    observerFrame = requestAnimationFrame(observeFrame);
    for (const side of sides) {
      const phase = observe.phase(engines[side]);
      const canvas = canvases[side];
      if (phase !== lastPhase[side]) {
        lastPhase[side] = phase;
        phases.push({ t: Date.now(), side, phase });
        if (canvas.log.length > 0) {
          draws.push({
            t: Date.now(),
            side,
            phase,
            ops: canvas.log.length,
            digest: digest(canvas.log),
          });
        }
      }
      canvas.clearLog();
    }
  };

  for (const side of sides) engines[side].start();
  if (mode === "solo") engines.host.beginMatch({ difficulty });
  observerFrame = requestAnimationFrame(observeFrame);

  for (const { at, side, key, down } of script) {
    setTimeout(() => {
      keyboards[side].dispatchEvent(
        new KeyboardEvent(down ? "keydown" : "keyup", { key, cancelable: true }),
      );
    }, at);
  }

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
