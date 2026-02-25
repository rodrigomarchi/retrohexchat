/**
 * Hex Skiing — Web Audio API synth effects.
 *
 * Zero external dependencies. All sounds synthesized at runtime.
 * Graceful fallback to no-op when AudioContext is unavailable.
 */

export class HexSkiingAudio {
  constructor() {
    this._ctx = null;
    this._droneOsc = null;
    this._droneGain = null;
    this._timers = [];
  }

  // ── Context management ─────────────────────────────────────

  _ensureContext() {
    if (this._ctx) {
      if (this._ctx.state === "suspended") {
        this._ctx.resume().catch(() => {});
      }
      return this._ctx;
    }
    try {
      this._ctx = new (window.AudioContext || window.webkitAudioContext)();
      return this._ctx;
    } catch {
      return null;
    }
  }

  // ── One-shot helpers ───────────────────────────────────────

  _playTone(freq, duration, type, volume) {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.value = volume;
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + duration);
  }

  _playSweep(startFreq, endFreq, duration, type, volume) {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.value = startFreq;
    osc.frequency.linearRampToValueAtTime(endFreq, ctx.currentTime + duration);
    gain.gain.value = volume;
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + duration);
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + duration);
  }

  // ── Persistent ski drone ───────────────────────────────────

  startSkiDrone() {
    const ctx = this._ensureContext();
    if (!ctx || this._droneOsc) return;
    this._droneOsc = ctx.createOscillator();
    this._droneGain = ctx.createGain();
    this._droneOsc.type = "sawtooth";
    this._droneOsc.frequency.value = 60;
    this._droneGain.gain.value = 0.03;
    this._droneOsc.connect(this._droneGain).connect(ctx.destination);
    this._droneOsc.start();
  }

  updateSkiPitch(speed) {
    if (!this._droneOsc || !this._ctx) return;
    // Map speed (0-4.5) to frequency (60-200Hz) and volume (0.02-0.06)
    const t = Math.min(speed / 4.5, 1);
    const freq = 60 + t * 140;
    const vol = 0.02 + t * 0.04;
    this._droneOsc.frequency.setTargetAtTime(freq, this._ctx.currentTime, 0.1);
    this._droneGain.gain.setTargetAtTime(vol, this._ctx.currentTime, 0.1);
  }

  stopSkiDrone() {
    if (this._droneOsc) {
      try {
        this._droneOsc.stop();
      } catch {
        // Already stopped
      }
      try {
        this._droneOsc.disconnect();
        this._droneGain.disconnect();
      } catch {
        // Already disconnected
      }
      this._droneOsc = null;
      this._droneGain = null;
    }
  }

  // ── Event sounds ───────────────────────────────────────────

  playTurn() {
    this._playSweep(400, 600, 0.06, "sine", 0.08);
  }

  playCollisionTree() {
    // Crack + poof
    this._playSweep(500, 80, 0.2, "sawtooth", 0.14);
    const ctx = this._ensureContext();
    if (!ctx) return;
    // Noise burst for snow poof
    this._timers.push(
      setTimeout(() => {
        this._playTone(120, 0.15, "triangle", 0.08);
      }, 50),
    );
  }

  playCollisionRock() {
    // Low thud
    this._playSweep(250, 40, 0.25, "sawtooth", 0.12);
  }

  playGateCleared() {
    // Satisfying ding arpeggio
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [523, 659, 784]; // C5, E5, G5
    notes.forEach((freq, i) => {
      this._timers.push(
        setTimeout(() => {
          this._playTone(freq, 0.1, "sine", 0.1);
        }, i * 50),
      );
    });
  }

  playSpeedBoost() {
    // Ascending whoosh
    this._playSweep(200, 800, 0.3, "sawtooth", 0.1);
  }

  playIcePatch() {
    // Slide sound
    this._playSweep(600, 200, 0.3, "triangle", 0.06);
  }

  playBlizzardStart() {
    // Wind crescendo
    this._playSweep(80, 300, 0.8, "triangle", 0.08);
  }

  playBlizzardEnd() {
    // Wind fade
    this._playSweep(300, 60, 0.6, "triangle", 0.06);
  }

  playAvalancheRumble(proximity) {
    // Low rumble, volume proportional to proximity (0-1)
    const vol = Math.min(0.1, proximity * 0.1);
    if (vol < 0.01) return;
    this._playTone(50 + proximity * 30, 0.3, "sawtooth", vol);
  }

  playEngulfed() {
    // Rumble max then silence
    this._playSweep(80, 20, 0.6, "sawtooth", 0.15);
  }

  playCountdown() {
    this._playTone(600, 0.08, "square", 0.1);
  }

  playCountdownGo() {
    this._playTone(900, 0.12, "square", 0.12);
  }

  playRoundEnd() {
    // Bell ding
    this._playTone(880, 0.3, "sine", 0.1);
    const ctx = this._ensureContext();
    if (ctx) {
      this._timers.push(setTimeout(() => this._playTone(1100, 0.4, "sine", 0.08), 150));
    }
  }

  playVictory() {
    // Ascending fanfare
    const notes = [523, 659, 784, 1047, 1319]; // C5-E6
    notes.forEach((freq, i) => {
      this._timers.push(
        setTimeout(() => {
          this._playTone(freq, 0.12, "square", 0.1);
        }, i * 120),
      );
    });
  }

  playGameOver() {
    this._playSweep(200, 30, 0.8, "sawtooth", 0.12);
  }

  // ── Cleanup ────────────────────────────────────────────────

  destroy() {
    // Clear all pending setTimeout callbacks
    for (const t of this._timers) {
      clearTimeout(t);
    }
    this._timers = [];
    this.stopSkiDrone();
    if (this._ctx) {
      this._ctx.close().catch(() => {});
      this._ctx = null;
    }
  }
}
