/**
 * The games' synthesizer: a sound is data, and this plays it.
 *
 * A sound is a voice, or a list of voices played together:
 *
 * ```js
 * { wave: "sawtooth", freq: glide(300, 100, 0.3), vol: fade(0.15, 0.3), dur: 0.3 }
 * { wave: "noise", vol: fade(0.1, 0.2, "exp"), dur: 0.2, filter: { type: "bandpass", freq: 800 } }
 * notes([400, 600, 800], { wave: "square", note: 0.12, vol: 0.12 })
 * ```
 *
 * `freq` and `vol` are a number, held for the whole voice, or a curve:
 * `[[op, value, at], …]` with `op` one of `set`, `linear`, `exp` (ramps to
 * the value by `at`) or `target` (`[op, value, at, timeConstant]`), and `at`
 * in seconds from the voice's start. `dur` is when an oscillator stops, and
 * how long a noise buffer runs; `delay` starts the voice later on the audio
 * clock.
 *
 * A held sound — an engine's hum, a drone — is a `tone`, moved with `set`
 * and ended with `stop`.
 *
 * The context opens on the first sound (browsers start audio only after a
 * user gesture) and is resumed by every sound; `dispose` closes it.
 *
 * @module games/core/synth
 */

/**
 * A pitch gliding from one frequency to another over `dur`.
 * @param {number} from
 * @param {number} to
 * @param {number} dur
 * @param {"linear"|"exp"} [kind]
 */
export function glide(from, to, dur, kind = "linear") {
  return [
    ["set", from, 0],
    [kind, to, dur],
  ];
}

/**
 * A volume fading to silence over `dur`: linearly to 0, or exponentially to
 * `floor` (an exponential ramp cannot reach 0).
 * @param {number} vol
 * @param {number} dur
 * @param {"linear"|"exp"} [kind]
 * @param {number} [floor]
 */
export function fade(vol, dur, kind = "linear", floor = 0.001) {
  return [["set", vol, 0], kind === "exp" ? ["exp", floor, dur] : ["linear", 0, dur]];
}

/**
 * Notes played one after another, each fading over its length.
 * @param {number[]} freqs
 * @param {{ wave: OscillatorType, note: number, vol: number, gap?: number, fadeKind?: "linear"|"exp" }} options
 */
export function notes(freqs, { wave, note, vol, gap = 0, fadeKind = "linear" }) {
  return freqs.map((freq, i) => ({
    wave,
    freq,
    vol: fade(vol, note, fadeKind),
    dur: note,
    delay: i * (note + gap),
  }));
}

const SCHEDULE = {
  set: "setValueAtTime",
  linear: "linearRampToValueAtTime",
  exp: "exponentialRampToValueAtTime",
};

/** Apply a number or a curve to an AudioParam, from `start`. */
function shape(param, value, start) {
  if (typeof value === "number") {
    param.setValueAtTime(value, start);
    return;
  }
  for (const [op, v, at, timeConstant] of value) {
    if (op === "target") param.setTargetAtTime(v, start + at, timeConstant);
    else param[SCHEDULE[op]](v, start + at);
  }
}

/**
 * @param {{ masterVolume?: number|null }} [options] - when set, every voice
 *   goes through one gain at this volume instead of straight to the speakers
 */
export function createSynth({ masterVolume = null } = {}) {
  let ctx = null;
  let master = null;

  const open = () => {
    if (!ctx) {
      const Context = globalThis.AudioContext || globalThis.webkitAudioContext;
      if (!Context) return null;
      try {
        ctx = new Context();
      } catch {
        return null;
      }
      if (masterVolume !== null) {
        master = ctx.createGain();
        master.gain.setValueAtTime(masterVolume, ctx.currentTime);
        master.connect(ctx.destination);
      }
    }
    // Best-effort: a context the browser keeps suspended plays nothing.
    if (ctx.state === "suspended") ctx.resume().catch(() => {});
    return ctx;
  };

  const output = () => master || ctx.destination;

  const filtered = (source, filter, start) => {
    if (!filter) return source;
    const node = ctx.createBiquadFilter();
    node.type = filter.type;
    if (filter.freq !== undefined) shape(node.frequency, filter.freq, start);
    if (filter.Q !== undefined) shape(node.Q, filter.Q, start);
    source.connect(node);
    return node;
  };

  const voice = ({ wave, freq, vol, dur, delay = 0, filter }) => {
    const start = ctx.currentTime + delay;
    let source;
    if (wave === "noise") {
      const length = ctx.sampleRate * dur;
      const buffer = ctx.createBuffer(1, length, ctx.sampleRate);
      const data = buffer.getChannelData(0);
      for (let i = 0; i < length; i++) data[i] = Math.random() * 2 - 1;
      source = ctx.createBufferSource();
      source.buffer = buffer;
    } else {
      source = ctx.createOscillator();
      source.type = wave;
      shape(source.frequency, freq, start);
    }
    const gain = ctx.createGain();
    shape(gain.gain, vol, start);
    filtered(source, filter, start).connect(gain);
    gain.connect(output());
    source.start(start);
    if (wave !== "noise") source.stop(start + dur);
  };

  return {
    /** The AudioContext, or null until the first sound. */
    get ctx() {
      return ctx;
    },

    /** @param {object|object[]} sound - a voice, or voices played together */
    play(sound) {
      if (!open()) return;
      for (const v of Array.isArray(sound) ? sound : [sound]) voice(v);
    },

    /**
     * A held tone, playing until stopped.
     * @param {{ wave: OscillatorType, freq: number, vol: number }} spec
     * @returns {{ set: (values: { freq?: number, vol?: number }, options?: { smooth?: number }) => void, stop: () => void }}
     */
    tone({ wave, freq, vol }) {
      if (!open()) return { set() {}, stop() {} };
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = wave;
      osc.frequency.setValueAtTime(freq, ctx.currentTime);
      gain.gain.setValueAtTime(vol, ctx.currentTime);
      osc.connect(gain);
      gain.connect(output());
      osc.start(ctx.currentTime);
      let playing = true;
      const move = (param, value, smooth) => {
        if (value === undefined) return;
        if (smooth) param.setTargetAtTime(value, ctx.currentTime, smooth);
        else param.setValueAtTime(value, ctx.currentTime);
      };
      return {
        set({ freq: f, vol: v }, { smooth } = {}) {
          if (!playing) return;
          move(osc.frequency, f, smooth);
          move(gain.gain, v, smooth);
        },
        stop() {
          if (!playing) return;
          playing = false;
          osc.stop(ctx.currentTime);
          gain.disconnect();
        },
      };
    },

    /**
     * Close the context: each one holds a real-time audio thread, and
     * browsers cap how many a page may open.
     */
    dispose() {
      if (!ctx) return;
      // Best-effort: a context that will not close is let go all the same.
      ctx.close().catch(() => {});
      ctx = null;
      master = null;
    },
  };
}

/**
 * A game's sounds, played by name: each entry of `sounds` becomes a method —
 * `paddleHit` is `playPaddleHit()`. An entry may be a function of the
 * method's arguments that returns the sound (a hit that rises with its
 * points). `extend` adds the game's held sounds (a hum that follows the
 * engine's speed), built on the same synthesizer.
 *
 * @param {{
 *   sounds?: Record<string, object | ((...args: unknown[]) => object)>,
 *   masterVolume?: number | null,
 *   extend?: (synth: ReturnType<typeof createSynth>) => Record<string, Function>,
 * }} spec
 */
export function createGameAudio({ sounds = {}, masterVolume = null, extend } = {}) {
  const synth = createSynth({ masterVolume });
  const audio = {
    /** The AudioContext, or null until the first sound. */
    get ctx() {
      return synth.ctx;
    },
    dispose: () => synth.dispose(),
  };
  for (const [name, sound] of Object.entries(sounds)) {
    const method = `play${name[0].toUpperCase()}${name.slice(1)}`;
    audio[method] = (...args) => synth.play(typeof sound === "function" ? sound(...args) : sound);
  }
  if (extend) Object.assign(audio, extend(synth));
  return audio;
}
