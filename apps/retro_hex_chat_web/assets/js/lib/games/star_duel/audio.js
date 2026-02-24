/**
 * Synth sound effects for Star Duel — cyberpunk space combat aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/star_duel_audio
 */

export class StarDuelAudio {
  constructor() {
    this._ctx = null;
    this._thrustOsc = null;
    this._thrustGain = null;
    this._proximityOsc = null;
    this._proximityGain = null;
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

  /** Thrust engine — looping low 50Hz sawtooth buzz. */
  playThrust() {
    const ctx = this._ensureContext();
    if (!ctx || this._thrustOsc) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.value = 50;
    gain.gain.value = 0.08;
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    this._thrustOsc = osc;
    this._thrustGain = gain;
  }

  /** Stop thrust engine loop. */
  stopThrust() {
    if (this._thrustOsc) {
      try {
        this._thrustOsc.stop();
      } catch {
        /* already stopped */
      }
      try {
        this._thrustGain.disconnect();
      } catch {
        /* already disconnected */
      }
      this._thrustOsc = null;
      this._thrustGain = null;
    }
  }

  /** Fire — laser zap: 1200Hz→200Hz sawtooth sweep, 100ms. */
  playFire() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(1200, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(200, ctx.currentTime + 0.1);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.1);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.1);
  }

  /** Hit — short metallic impact: 600Hz square, 80ms. */
  playHit() {
    this._playTone(600, 0.08, "square", 0.15);
  }

  /** Death — heavy explosion: 200→50Hz sawtooth, 400ms. */
  playDeath() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(200, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(50, ctx.currentTime + 0.4);
    gain.gain.setValueAtTime(0.2, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.4);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.4);
  }

  /** Warp — phaser sweep: 300→2000→300Hz sine, 300ms. */
  playWarp() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(300, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(2000, ctx.currentTime + 0.15);
    osc.frequency.linearRampToValueAtTime(300, ctx.currentTime + 0.3);
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.3);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.3);
  }

  /** Star proximity drone (Gravity Well) — sine tone, volume based on distance. */
  playStarProximity(distance) {
    const ctx = this._ensureContext();
    if (!ctx) return;
    // Volume inversely proportional to distance, capped
    const maxDist = 300;
    const vol = Math.max(0, Math.min(0.15, (1 - distance / maxDist) * 0.15));

    if (!this._proximityOsc) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.value = 80;
      gain.gain.value = vol;
      osc.connect(gain).connect(ctx.destination);
      osc.start();
      this._proximityOsc = osc;
      this._proximityGain = gain;
    } else if (this._proximityGain) {
      this._proximityGain.gain.setTargetAtTime(vol, ctx.currentTime, 0.02);
    }
  }

  /** Stop star proximity drone. */
  stopStarProximity() {
    if (this._proximityOsc) {
      try {
        this._proximityOsc.stop();
      } catch {
        /* already stopped */
      }
      try {
        this._proximityGain.disconnect();
      } catch {
        /* already disconnected */
      }
      this._proximityOsc = null;
      this._proximityGain = null;
    }
  }

  /** Countdown tick — 600Hz square blip, 80ms (same as pong). */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Win — ascending arpeggio 400→600→800→1000Hz. */
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

  /** Spawn — rising blip: 200→800Hz sine, 150ms. */
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

  /**
   * Generic single-tone helper.
   * @param {number} freq
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
