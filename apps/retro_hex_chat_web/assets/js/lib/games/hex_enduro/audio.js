/**
 * Procedural audio synthesis for Hex Enduro.
 * All sounds use Web Audio API oscillators — no external audio files.
 * Includes persistent engine drone that modulates with speed.
 * @module games/hex_enduro_audio
 */

export class HexEnduroAudio {
  constructor() {
    this._ctx = null;
    this._droneOsc = null;
    this._droneGain = null;
  }

  _ensureContext() {
    if (this._ctx) {
      if (this._ctx.state === "suspended") this._ctx.resume();
      return this._ctx;
    }
    if (typeof AudioContext === "undefined") return null;
    try {
      this._ctx = new AudioContext();
      if (this._ctx.state === "suspended") this._ctx.resume();
      return this._ctx;
    } catch {
      return null;
    }
  }

  _playTone(freq, duration, type, volume) {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    gain.gain.setValueAtTime(volume, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration);
  }

  _playSweep(startFreq, endFreq, duration, type, volume) {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(startFreq, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(endFreq, ctx.currentTime + duration);
    gain.gain.setValueAtTime(volume, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + duration);
  }

  /** Start persistent engine drone. Pitch tied to speed. */
  startEngineDrone() {
    const ctx = this._ensureContext();
    if (!ctx || this._droneOsc) return;
    this._droneOsc = ctx.createOscillator();
    this._droneGain = ctx.createGain();
    this._droneOsc.type = "sawtooth";
    this._droneOsc.frequency.setValueAtTime(80, ctx.currentTime);
    this._droneGain.gain.setValueAtTime(0.04, ctx.currentTime);
    this._droneOsc.connect(this._droneGain);
    this._droneGain.connect(ctx.destination);
    this._droneOsc.start(ctx.currentTime);
  }

  /** Update engine drone pitch based on speed (0-1000). */
  updateEnginePitch(speed) {
    if (!this._droneOsc || !this._ctx) return;
    // Map speed 0-1000 to frequency 80-350Hz
    const freq = 80 + (speed / 1000) * 270;
    const vol = 0.02 + (speed / 1000) * 0.06;
    this._droneOsc.frequency.setTargetAtTime(freq, this._ctx.currentTime, 0.1);
    this._droneGain.gain.setTargetAtTime(vol, this._ctx.currentTime, 0.1);
  }

  /** Stop engine drone. */
  stopEngineDrone() {
    if (this._droneOsc) {
      try {
        this._droneOsc.stop();
      } catch {
        /* already stopped */
      }
      this._droneOsc = null;
      this._droneGain = null;
    }
  }

  /** Lane change: quick sine sweep 400->600Hz */
  playLaneChange() {
    this._playSweep(400, 600, 0.06, "sine", 0.1);
  }

  /** Turbo activate: sawtooth ramp 200->800Hz */
  playTurbo() {
    this._playSweep(200, 800, 0.3, "sawtooth", 0.12);
  }

  /** AI car overtake: 2-note ascending chirp */
  playOvertakeAI() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    [500, 700].forEach((freq, i) => {
      const t = ctx.currentTime + i * 0.06;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0.08, t);
      gain.gain.linearRampToValueAtTime(0, t + 0.05);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.05);
    });
  }

  /** Player overtake: 3-note ascending fanfare */
  playOvertakePlayer() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    [500, 700, 900].forEach((freq, i) => {
      const t = ctx.currentTime + i * 0.08;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0.1, t);
      gain.gain.linearRampToValueAtTime(0, t + 0.07);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.07);
    });
  }

  /** Collision: sawtooth explosion 300->50Hz */
  playCollision() {
    this._playSweep(300, 50, 0.3, "sawtooth", 0.15);
  }

  /** Fuel pickup: sparkle arpeggio C5-E5-G5 */
  playFuelPickup() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    [523, 659, 784].forEach((freq, i) => {
      const t = ctx.currentTime + i * 0.06;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0.1, t);
      gain.gain.linearRampToValueAtTime(0, t + 0.08);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.08);
    });
  }

  /** Weather change: low triangle rumble */
  playWeatherChange() {
    this._playTone(80, 0.5, "triangle", 0.08);
  }

  /** Countdown tick */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.1);
  }

  /** Victory fanfare: ascending 5-note */
  playVictory() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    [523, 659, 784, 1047, 1319].forEach((freq, i) => {
      const t = ctx.currentTime + i * 0.12;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "square";
      osc.frequency.setValueAtTime(freq, t);
      gain.gain.setValueAtTime(0.1, t);
      gain.gain.linearRampToValueAtTime(0, t + 0.1);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.1);
    });
  }

  /** Game over: descending sawtooth */
  playGameOver() {
    this._playSweep(200, 30, 0.8, "sawtooth", 0.12);
  }

  /** Fuel warning: rapid square pulse */
  playFuelWarning() {
    this._playTone(800, 0.03, "square", 0.06);
  }

  /** Clean up all audio resources. */
  destroy() {
    this.stopEngineDrone();
    if (this._ctx) {
      try {
        this._ctx.close();
      } catch {
        /* already closed */
      }
      this._ctx = null;
    }
  }
}
