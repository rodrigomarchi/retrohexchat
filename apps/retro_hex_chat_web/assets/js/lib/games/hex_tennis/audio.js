/**
 * Synth sound effects for Hex Tennis — cyberpunk aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/hex_tennis/audio
 */

export class TennisAudio {
  constructor() {
    this._ctx = null;
  }

  /** Lazy-init AudioContext on first sound (browser requires user gesture). */
  _ensureContext() {
    if (!this._ctx) {
      try {
        this._ctx = new (window.AudioContext || window.webkitAudioContext)();
      } catch {
        return null;
      }
    }
    if (this._ctx.state === "suspended") {
      this._ctx.resume().catch(() => {});
    }
    return this._ctx;
  }

  /** Racket hit — bright twang: 1200→600Hz sawtooth, 80ms. */
  playHit() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(1200, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(600, ctx.currentTime + 0.08);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.08);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.08);
  }

  /** Serve — rising swoosh: 200→800Hz sawtooth, 150ms. */
  playServe() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(200, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(800, ctx.currentTime + 0.15);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.15);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.15);
  }

  /** Net hit — dull thud: 150Hz square, 100ms. */
  playNetHit() {
    this._playTone(150, 0.1, "square", 0.1);
  }

  /** Out of bounds — descending buzz: 500→200Hz sawtooth, 200ms. */
  playOut() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(500, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(200, ctx.currentTime + 0.2);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.2);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.2);
  }

  /** Point scored — brief arpeggio: 600→800→600Hz triangle, 300ms. */
  playPoint() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [600, 800, 600];
    const noteLen = 0.1;
    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "triangle";
      osc.frequency.value = freq;
      const start = ctx.currentTime + i * noteLen;
      gain.gain.setValueAtTime(0.1, start);
      gain.gain.linearRampToValueAtTime(0, start + noteLen);
      osc.connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + noteLen);
    });
  }

  /** Game won — ascending arpeggio: 400→500→600→800Hz square, 400ms. */
  playGameWon() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [400, 500, 600, 800];
    const noteLen = 0.1;
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

  /** Match won — full fanfare: 400→600→800→1000→1200Hz square, 600ms. */
  playMatchWon() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [400, 600, 800, 1000, 1200];
    const noteLen = 0.12;
    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      osc.frequency.value = freq;
      const start = ctx.currentTime + i * noteLen;
      gain.gain.setValueAtTime(0.14, start);
      gain.gain.linearRampToValueAtTime(0, start + noteLen);
      osc.connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + noteLen);
    });
  }

  /** Fault — short buzz: 300Hz square, 60ms. */
  playFault() {
    this._playTone(300, 0.06, "square", 0.1);
  }

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Bounce — soft tap: 500Hz triangle, 30ms. */
  playBounce() {
    this._playTone(500, 0.03, "triangle", 0.06);
  }

  /** Ace — rising tone: 800→1200Hz sawtooth, 200ms. */
  playAce() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(800, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(1200, ctx.currentTime + 0.2);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.2);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.2);
  }

  /** Close the AudioContext to free resources. */
  dispose() {
    if (this._ctx) {
      this._ctx.close().catch(() => {});
      this._ctx = null;
    }
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
    if (!ctx) return;
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
