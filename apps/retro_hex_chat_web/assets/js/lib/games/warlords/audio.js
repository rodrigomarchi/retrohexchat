/**
 * Synth sound effects for Hex Warlords — castle battle aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/warlords_audio
 */

export class WarlordAudio {
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

  /** Brick hit — 800Hz triangle, 40ms crispy break. */
  playBrickHit() {
    this._playTone(800, 0.04, "triangle", 0.12);
  }

  /** Shield deflect — 1200Hz sine, 30ms metallic ping. */
  playShieldDeflect() {
    this._playTone(1200, 0.03, "sine", 0.15);
  }

  /** King hit — descending 200->50Hz sawtooth sweep, 500ms explosion. */
  playKingHit() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(200, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(50, ctx.currentTime + 0.5);
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.5);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.5);
  }

  /** Catch — ascending 400->800Hz sine sweep, 200ms energy charge. */
  playCatch() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(400, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(800, ctx.currentTime + 0.2);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.2);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.2);
  }

  /** Launch — descending 800->400Hz sine, 150ms whoosh. */
  playLaunch() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(800, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(400, ctx.currentTime + 0.15);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.15);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.15);
  }

  /** Wall bounce — 300Hz square, 30ms. */
  playWallBounce() {
    this._playTone(300, 0.03, "square", 0.1);
  }

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Win — ascending arpeggio C-E-G-C-E (triumphant fanfare). */
  playWin() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [523, 659, 784, 1047, 1319]; // C5-E5-G5-C6-E6
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

  /** Lose — descending 500->150Hz sawtooth, 700ms defeat. */
  playLose() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(500, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(150, ctx.currentTime + 0.7);
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.7);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.7);
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
