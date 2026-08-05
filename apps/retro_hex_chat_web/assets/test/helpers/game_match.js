import { vi } from "vitest";

/**
 * An in-process match between two real engines.
 *
 * The unit tests around each game drive one engine and assert on its internals.
 * That is not where these games broke: every real defect in the fixed-clock
 * rewrite lived in the *seam* — a guest that never drew, a host whose frame loop
 * was cancelled the moment play began, a mechanic that only fires on the guest's
 * key release, a handshake that hung the match when its one datagram was lost.
 *
 * So this wires a host engine and a guest engine to each other through paired
 * channels, drives both off one deterministic clock, and lets a test play the
 * match. Packet loss is a parameter because the game channel does not
 * retransmit, and "works on loopback" is exactly the illusion that hid the
 * handshake bug.
 *
 * @module helpers/game_match
 */

/** One simulation step, matching the engine's fixed clock. */
const STEP_MS = 1000 / 60;

/**
 * A canvas context that accepts anything a renderer asks of it.
 *
 * Fifteen games draw through this, each using a different slice of the 2D API.
 * Enumerating those slices would be a second, worse copy of the renderers.
 */
function stubContext() {
  const gradient = { addColorStop: () => {} };

  return new Proxy(
    {},
    {
      get(target, prop) {
        if (prop in target) return target[prop];
        if (prop === "canvas") return undefined;
        if (typeof prop !== "string") return undefined;
        if (prop.startsWith("create") && prop.endsWith("Gradient")) return () => gradient;
        if (prop === "createPattern") return () => ({});
        if (prop === "measureText") return () => ({ width: 10 });
        if (prop === "getImageData") return () => ({ data: new Uint8ClampedArray(4) });
        return () => {};
      },
      set(target, prop, value) {
        target[prop] = value;
        return true;
      },
    },
  );
}

function stubCanvas(width, height) {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = stubContext();
  canvas.getContext = () => ctx;
  return canvas;
}

/**
 * A DataChannel pair. `send` on one end delivers to the other end's listeners,
 * subject to the loss model.
 */
function createChannelPair(shouldDrop) {
  const ends = [makeEnd(), makeEnd()];
  ends[0]._peer = ends[1];
  ends[1]._peer = ends[0];
  return ends;

  function makeEnd() {
    const listeners = { message: [], close: [] };

    return {
      readyState: "open",
      bufferedAmount: 0,
      sent: [],
      addEventListener: (type, fn) => listeners[type]?.push(fn),
      removeEventListener: (type, fn) => {
        const list = listeners[type];
        if (list) list.splice(list.indexOf(fn), 1);
      },
      send(data) {
        this.sent.push(data);
        if (shouldDrop(data, this)) return;
        for (const fn of this._peer._listeners.message) fn({ data });
      },
      get _listeners() {
        return listeners;
      },
    };
  }
}

/**
 * Start a match between two engines of the same game.
 *
 * @param {typeof import("../../js/lib/game_engine.js").GameEngine} EngineClass
 * @param {string} gameId
 * @param {object} [options]
 * @param {(data: ArrayBuffer, from: object) => boolean} [options.drop] - Loss model.
 * @param {number} [options.width]
 * @param {number} [options.height]
 * @returns {{host: object, guest: object, advance: (ms: number) => void,
 *   results: {host: object[], guest: object[]}, hostChannel: object,
 *   guestChannel: object, stop: () => void}}
 */
export function startMatch(EngineClass, gameId, options = {}) {
  const { drop = () => false, width = 640, height = 480 } = options;

  // A real frame queue rather than a no-op, because "the engine stopped asking
  // for frames" is a failure mode: cancelling the pending frame inside
  // _startGameLoop froze four games the moment play began. Driving _pump
  // directly would hide exactly that.
  const frames = new Map();
  let nextHandle = 1;

  vi.stubGlobal("requestAnimationFrame", (callback) => {
    const handle = nextHandle++;
    frames.set(handle, callback);
    return handle;
  });
  vi.stubGlobal("cancelAnimationFrame", (handle) => frames.delete(handle));
  stubAudioContext();

  const [hostChannel, guestChannel] = createChannelPair(drop);
  const results = { host: [], guest: [] };

  const host = new EngineClass(stubCanvas(width, height), hostChannel, gameId, true, (r) =>
    results.host.push(r),
  );
  const guest = new EngineClass(stubCanvas(width, height), guestChannel, gameId, false, (r) =>
    results.guest.push(r),
  );

  let clock = 0;
  for (const engine of [host, guest]) engine._now = () => clock;

  host.start();
  guest.start();

  return {
    host,
    guest,
    hostChannel,
    guestChannel,
    results,

    /**
     * Advance the match by wall-clock milliseconds, running whatever frames the
     * engines asked for and letting their timers fire alongside.
     * @param {number} ms
     */
    advance(ms) {
      const target = clock + ms;
      while (clock < target) {
        clock = Math.min(target, clock + STEP_MS);

        // Snapshot first: a callback re-requests its next frame, and that one
        // belongs to the frame after this.
        const due = [...frames.entries()];
        for (const [handle, callback] of due) {
          frames.delete(handle);
          callback(clock);
        }

        vi.advanceTimersByTime(STEP_MS);
      }
    },

    /** How many frames the engines currently have outstanding. */
    pendingFrames() {
      return frames.size;
    },

    stop() {
      host.stop();
      guest.stop();
    },
  };
}

/**
 * jsdom has no Web Audio. Every game lazily builds an AudioContext and swallows
 * the failure, so a stub keeps the audio paths exercised rather than skipped.
 * @returns {void}
 */
function stubAudioContext() {
  const node = () => ({
    connect: () => node(),
    disconnect: () => {},
    start: () => {},
    stop: () => {},
    frequency: { value: 0, setValueAtTime: () => {}, linearRampToValueAtTime: () => {} },
    gain: {
      value: 0,
      setValueAtTime: () => {},
      linearRampToValueAtTime: () => {},
      exponentialRampToValueAtTime: () => {},
      setTargetAtTime: () => {},
      cancelScheduledValues: () => {},
    },
    type: "sine",
    buffer: null,
    playbackRate: { value: 1 },
  });

  class FakeAudioContext {
    constructor() {
      this.state = "running";
      this.currentTime = 0;
      this.destination = node();
      this.sampleRate = 48_000;
    }
    createOscillator = node;
    createGain = node;
    createBufferSource = node;
    createBiquadFilter = () => ({ ...node(), Q: { value: 1 } });
    createBuffer = () => ({ getChannelData: () => new Float32Array(1) });
    createDynamicsCompressor = node;
    createStereoPanner = () => ({ ...node(), pan: { value: 0 } });
    resume = () => Promise.resolve();
    close = () => Promise.resolve();
  }

  vi.stubGlobal("AudioContext", FakeAudioContext);
  vi.stubGlobal("webkitAudioContext", FakeAudioContext);
}

/**
 * A loss model that drops the first `count` datagrams matching `match`.
 * @param {number} count
 * @param {(data: ArrayBuffer) => boolean} match
 * @returns {(data: ArrayBuffer) => boolean}
 */
export function dropFirst(count, match = () => true) {
  let remaining = count;
  return (data) => {
    if (remaining > 0 && match(data)) {
      remaining -= 1;
      return true;
    }
    return false;
  };
}

/**
 * Read the message type byte, for loss models that target one kind of message.
 * @param {ArrayBuffer} data
 * @returns {number}
 */
export function messageType(data) {
  return data.byteLength ? new DataView(data).getUint8(0) : -1;
}
