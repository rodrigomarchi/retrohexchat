import { vi } from "vitest";

/**
 * Replace the page's AudioContext with one that records every call a game
 * makes to build its sounds, in order: which nodes it creates, how it sets and
 * automates their parameters, how it wires them and when it starts and stops
 * them. Two sound implementations are the same sound when their logs match.
 *
 * The audio clock reads the test clock (`performance.now()`), so a log is the
 * same on every run.
 *
 * Each entry's context is kept beside the log, so the sounds of two players
 * sharing one page can be told apart (`entriesOf(context)`).
 *
 * @returns {{ log: Array<Array<unknown>>, entriesOf: (context: object) => Array<Array<unknown>> }}
 */
export function recordingAudio() {
  const log = [];
  const owners = [];
  let nextId = 1;
  let nextContext = 1;
  // Each entry also carries the audio clock's time as `entry.t`, a hidden
  // property: comparisons, digests and JSON of the log leave it out.
  const push = (entry, context) => {
    Object.defineProperty(entry, "t", { value: performance.now() / 1000 });
    log.push(entry);
    owners.push(context);
  };

  const param = (nodeId, context, name, initial) => {
    const label = `${nodeId}.${name}`;
    let value = initial;
    const record =
      (op) =>
      (...args) => {
        push([label, op, ...args], context);
        return target;
      };
    const target = {
      get value() {
        return value;
      },
      set value(next) {
        value = next;
        push([label, "value", next], context);
      },
      setValueAtTime: record("setValueAtTime"),
      linearRampToValueAtTime: record("linearRampToValueAtTime"),
      exponentialRampToValueAtTime: record("exponentialRampToValueAtTime"),
      setTargetAtTime: record("setTargetAtTime"),
      setValueCurveAtTime: record("setValueCurveAtTime"),
      cancelScheduledValues: record("cancelScheduledValues"),
      cancelAndHoldAtTime: record("cancelAndHoldAtTime"),
    };
    return target;
  };

  const node = (context, kind, params = {}, fields = {}) => {
    const id = `n${nextId++}`;
    push([id, kind], context);
    const state = { ...fields };
    const target = {
      id,
      connect(destination) {
        push([id, "connect", destination?.id ?? "?"], context);
        return destination;
      },
      disconnect(...args) {
        push([id, "disconnect", ...args.map((arg) => arg?.id ?? arg)], context);
      },
      start(...args) {
        push([id, "start", ...args], context);
      },
      stop(...args) {
        push([id, "stop", ...args], context);
      },
      addEventListener() {},
      removeEventListener() {},
      onended: null,
    };
    for (const [name, initial] of Object.entries(params)) {
      target[name] = param(id, context, name, initial);
    }
    for (const name of Object.keys(fields)) {
      Object.defineProperty(target, name, {
        get: () => state[name],
        set: (value) => {
          state[name] = value;
          push([id, name, value?.id ?? value], context);
        },
      });
    }
    return target;
  };

  class RecordingAudioContext {
    constructor() {
      this.id = `c${nextContext++}`;
      push(["context", "new"], this);
      this.state = "running";
      this.sampleRate = 48_000;
      this.destination = { id: "destination" };
    }

    get currentTime() {
      return performance.now() / 1000;
    }

    createOscillator() {
      return node(this, "createOscillator", { frequency: 440, detune: 0 }, { type: "sine" });
    }

    createGain() {
      return node(this, "createGain", { gain: 1 });
    }

    createBiquadFilter() {
      return node(
        this,
        "createBiquadFilter",
        { frequency: 350, Q: 1, gain: 0 },
        { type: "lowpass" },
      );
    }

    createBufferSource() {
      return node(
        this,
        "createBufferSource",
        { playbackRate: 1, detune: 0 },
        { buffer: null, loop: false },
      );
    }

    createStereoPanner() {
      return node(this, "createStereoPanner", { pan: 0 });
    }

    createDynamicsCompressor() {
      return node(this, "createDynamicsCompressor", {
        threshold: -24,
        knee: 30,
        ratio: 12,
        attack: 0.003,
        release: 0.25,
      });
    }

    createDelay() {
      return node(this, "createDelay", { delayTime: 0 });
    }

    createBuffer(channels, length, sampleRate) {
      const id = `b${nextId++}`;
      push([id, "createBuffer", channels, length, sampleRate], this);
      const data = Array.from({ length: channels }, () => new Float32Array(length));
      return { id, length, sampleRate, numberOfChannels: channels, getChannelData: (i) => data[i] };
    }

    resume() {
      return Promise.resolve();
    }

    close() {
      push(["context", "close"], this);
      this.state = "closed";
      return Promise.resolve();
    }
  }

  vi.stubGlobal("AudioContext", RecordingAudioContext);
  vi.stubGlobal("webkitAudioContext", RecordingAudioContext);

  return {
    log,
    entriesOf: (context) => log.filter((_entry, index) => owners[index] === context),
  };
}
