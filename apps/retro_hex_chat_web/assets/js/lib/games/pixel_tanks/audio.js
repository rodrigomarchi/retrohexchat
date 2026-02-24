/**
 * Synth sound effects for Pixel Tanks — wasteland combat aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/pixel_tanks_audio
 */

export class PixelTanksAudio {
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

  /** Cannon fire — descending 400->100Hz sawtooth, 150ms heavy blast. */
  playFire() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(400, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, ctx.currentTime + 0.15);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.15);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.15);
  }

  /** Tank hit — descending 300->60Hz sawtooth explosion, 300ms. */
  playHit() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(300, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(60, ctx.currentTime + 0.3);
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.3);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.3);
  }

  /** Ricochet — bright metallic ping 2000Hz, 50ms. */
  playRicochet() {
    this._playTone(2000, 0.05, "sine", 0.12);
  }

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Spawn — ascending 200->800Hz sine, 150ms energy charge. */
  playSpawn() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(200, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(800, ctx.currentTime + 0.15);
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.15);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.15);
  }

  /** Timer tick — 800Hz square, 30ms subtle click (last 15s). */
  playTimerTick() {
    this._playTone(800, 0.03, "square", 0.06);
  }

  /** Round end — 3-note fanfare. */
  playRoundEnd() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [440, 554, 659]; // A4-C#5-E5
    const noteLen = 0.15;
    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      osc.frequency.value = freq;
      const start = ctx.currentTime + i * noteLen;
      gain.gain.setValueAtTime(0.1, start);
      gain.gain.linearRampToValueAtTime(0, start + noteLen);
      osc.connect(gain).connect(ctx.destination);
      osc.start(start);
      osc.stop(start + noteLen);
    });
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
