/**
 * Synth sound effects for Hex Pong — cyberpunk aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/pong_audio
 */

export class PongAudio {
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

  /** Paddle hit — 800Hz sawtooth, 60ms. */
  playPaddleHit() {
    this._playTone(800, 0.06, "sawtooth", 0.15);
  }

  /** Wall bounce — 400Hz square, 40ms. */
  playWallBounce() {
    this._playTone(400, 0.04, "square", 0.1);
  }

  /** Score — descending 300→100Hz sawtooth, 300ms. */
  playScore() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(300, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, ctx.currentTime + 0.3);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.3);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.3);
  }

  /** Win — ascending arpeggio 400→600→800→1000Hz, 500ms total. */
  playWin() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [400, 600, 800, 1000];
    const noteLen = 0.12;

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

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
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
