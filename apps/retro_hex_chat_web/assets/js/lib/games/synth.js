/**
 * Base for every game's synthesizer: owns the one AudioContext a game opens
 * and the plain tone most sounds are built from. Each game's audio module
 * extends it and keeps only its own sounds.
 * @module games/synth
 */

export class GameSynth {
  /**
   * @param {object} [options]
   * @param {number|null} [options.masterVolume] - when set, every sound goes
   *   through one gain node at this volume instead of straight to the speakers.
   */
  constructor({ masterVolume = null } = {}) {
    /** @type {AudioContext|null} */
    this._ctx = null;
    /** @type {GainNode|null} */
    this._master = null;
    this._masterVolume = masterVolume;
  }

  /** The AudioContext, or null until the first sound (or when unavailable). */
  get ctx() {
    return this._ctx;
  }

  /**
   * The context, opened on the first sound: browsers only let audio start
   * after a user gesture, and a context opened earlier stays suspended until
   * it is resumed — so every sound resumes it.
   * @returns {AudioContext|null}
   */
  _ensureContext() {
    if (!this._ctx) {
      if (!window.AudioContext && !window.webkitAudioContext) return null;
      try {
        this._ctx = new (window.AudioContext || window.webkitAudioContext)();
      } catch {
        return null;
      }
      if (this._masterVolume !== null) {
        this._master = this._ctx.createGain();
        this._master.gain.value = this._masterVolume;
        this._master.connect(this._ctx.destination);
      }
    }
    if (this._ctx.state === "suspended") {
      this._ctx.resume().catch(() => {});
    }
    return this._ctx;
  }

  /** Where a sound connects: the master gain when there is one, else the speakers. */
  get _output() {
    return this._master || this._ctx.destination;
  }

  /**
   * One oscillator note that fades linearly to silence.
   * @param {number} freq - Hz
   * @param {number} duration - seconds
   * @param {OscillatorType} type
   * @param {number} volume - 0..1
   */
  _playTone(freq, duration, type, volume) {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(volume, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(this._output);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration);
  }

  /**
   * Release the AudioContext. Each one holds a real-time audio thread for as
   * long as it lives, and browsers cap how many a page may open.
   * @returns {void}
   */
  dispose() {
    if (this._ctx) {
      this._ctx.close().catch(() => {});
      this._ctx = null;
      this._master = null;
    }
  }
}
