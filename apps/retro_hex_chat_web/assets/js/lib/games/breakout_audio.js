/**
 * Synth sound effects for Block Breakers — cyberpunk cooperative aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/breakout_audio
 */

export class BreakoutAudio {
  constructor() {
    this._ctx = null;
  }

  /** Lazy-init AudioContext on first sound (browser requires user gesture). */
  _ensureContext() {
    if (!this._ctx) {
      this._ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (this._ctx.state === "suspended") {
      this._ctx.resume();
    }
    return this._ctx;
  }

  /** Paddle hit — 600Hz triangle, 50ms. */
  playPaddleHit() {
    this._playTone(600, 0.05, "triangle", 0.15);
  }

  /** Wall bounce — 300Hz square, 30ms. */
  playWallBounce() {
    this._playTone(300, 0.03, "square", 0.1);
  }

  /**
   * Block hit — pitch varies by row (higher rows = higher pitch).
   * @param {number} row - 0 (top) to 4 (bottom)
   */
  playBlockHit(row) {
    const baseFreq = 800;
    const freq = baseFreq + (4 - row) * 100; // Row 0 = 1200Hz, Row 4 = 800Hz
    this._playTone(freq, 0.04, "sawtooth", 0.12);
  }

  /** Life lost — descending 400->100Hz sawtooth, 400ms. */
  playLifeLost() {
    const ctx = this._ensureContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(400, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, ctx.currentTime + 0.4);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.4);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.4);
  }

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Win — ascending arpeggio C-E-G-C (triumphant). */
  playWin() {
    const ctx = this._ensureContext();
    const notes = [523, 659, 784, 1047]; // C5-E5-G5-C6
    const noteLen = 0.15;

    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      osc.frequency.value = freq;
      const start = ctx.currentTime + i * noteLen;
      gain.gain.setValueAtTime(0.12, start);
      gain.gain.linearRampToValueAtTime(0, start + noteLen);
      osc.connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + noteLen);
    });
  }

  /** Lose — descending chromatic 500->200Hz, 600ms. */
  playLose() {
    const ctx = this._ensureContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(500, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(200, ctx.currentTime + 0.6);
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.6);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.6);
  }

  /**
   * Generic single-tone helper.
   * @param {number} freq - frequency in Hz
   * @param {number} duration - seconds
   * @param {string} type - oscillator type
   * @param {number} volume - gain (0-1)
   */
  _playTone(freq, duration, type, volume) {
    const ctx = this._ensureContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(volume, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration);
  }
}
