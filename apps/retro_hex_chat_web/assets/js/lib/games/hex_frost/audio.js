/**
 * Hex Frost — Web Audio API synthesizer.
 *
 * All sounds are generated procedurally. Zero external dependencies.
 * Arctic cyberpunk aesthetic: crystalline plings, icy rumbles, howling wind.
 */

export class HexFrostAudio {
  constructor() {
    try {
      this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.3;
      this.master.connect(this.ctx.destination);
    } catch {
      this.ctx = null;
      this.master = null;
    }
    this._windOsc = null;
    this._windGain = null;
    this._timers = [];
  }

  // ── Helpers ──────────────────────────────────────────────────

  _playTone(freq, duration, type = "square", volume = 0.3) {
    if (!this.ctx) return;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(volume, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(this.master);
    osc.start(this.ctx.currentTime);
    osc.stop(this.ctx.currentTime + duration);
  }

  _playSweep(startFreq, endFreq, duration, type = "square", volume = 0.3) {
    if (!this.ctx) return;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(startFreq, this.ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(
      Math.max(endFreq, 20),
      this.ctx.currentTime + duration,
    );
    gain.gain.setValueAtTime(volume, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
    osc.connect(gain);
    gain.connect(this.master);
    osc.start(this.ctx.currentTime);
    osc.stop(this.ctx.currentTime + duration);
  }

  _playNoise(duration, volume = 0.15) {
    if (!this.ctx) return;
    const bufferSize = this.ctx.sampleRate * duration;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    const source = this.ctx.createBufferSource();
    source.buffer = buffer;
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(volume, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
    source.connect(gain);
    gain.connect(this.master);
    source.start(this.ctx.currentTime);
  }

  // ── Game sounds ──────────────────────────────────────────────

  playJump() {
    this._playSweep(200, 500, 0.12, "sine", 0.25);
  }

  playLand() {
    this._playNoise(0.06, 0.1);
    this._playTone(80, 0.08, "sine", 0.15);
  }

  playBlockClaim() {
    // Crystalline pling — ascending
    this._playTone(800, 0.08, "sine", 0.2);
    const t = setTimeout(() => this._playTone(1200, 0.1, "sine", 0.15), 40);
    this._timers.push(t);
  }

  playBlockSteal() {
    // Crystalline pling + alarm
    this._playTone(1000, 0.08, "sine", 0.25);
    const t1 = setTimeout(() => this._playTone(1400, 0.1, "sine", 0.2), 40);
    const t2 = setTimeout(() => this._playSweep(600, 200, 0.15, "sawtooth", 0.12), 80);
    this._timers.push(t1, t2);
  }

  playBlockUndo() {
    // Error buzz
    this._playSweep(300, 100, 0.15, "sawtooth", 0.2);
  }

  playIglooPiece() {
    // Satisfying building block sound
    this._playTone(440, 0.06, "square", 0.15);
    const t = setTimeout(() => this._playTone(660, 0.08, "square", 0.12), 50);
    this._timers.push(t);
  }

  playIglooLose() {
    // Crumble sound
    this._playSweep(400, 80, 0.2, "sawtooth", 0.2);
    this._playNoise(0.15, 0.1);
  }

  playIglooComplete() {
    // Fanfare — 3 ascending notes
    this._playTone(523, 0.12, "square", 0.2);
    const t1 = setTimeout(() => this._playTone(659, 0.12, "square", 0.2), 120);
    const t2 = setTimeout(() => this._playTone(784, 0.2, "square", 0.25), 240);
    this._timers.push(t1, t2);
  }

  playIglooEnter() {
    // Door close + warm sound
    this._playNoise(0.08, 0.12);
    this._playTone(200, 0.15, "sine", 0.15);
    const t = setTimeout(() => this._playSweep(300, 500, 0.3, "sine", 0.1), 100);
    this._timers.push(t);
  }

  playSplash() {
    // Water splash
    this._playNoise(0.2, 0.2);
    this._playSweep(400, 100, 0.2, "sine", 0.15);
  }

  playFishCollect() {
    // Splash + bonus pling
    this._playNoise(0.08, 0.08);
    this._playTone(880, 0.06, "sine", 0.2);
    const t = setTimeout(() => this._playTone(1100, 0.1, "sine", 0.15), 60);
    this._timers.push(t);
  }

  playEnemyHit() {
    // Impact
    this._playNoise(0.1, 0.2);
    this._playSweep(500, 80, 0.25, "sawtooth", 0.25);
  }

  playBearNear() {
    // Low growl rumble
    if (!this.ctx) return;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.value = 40;
    gain.gain.setValueAtTime(0.08, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.3);
    osc.connect(gain);
    gain.connect(this.master);
    osc.start(this.ctx.currentTime);
    osc.stop(this.ctx.currentTime + 0.3);
  }

  playClamSnap() {
    // Sharp snap
    this._playNoise(0.03, 0.2);
    this._playTone(1500, 0.04, "square", 0.15);
  }

  playTempLow() {
    // Wind howl — filtered noise
    if (!this.ctx) return;
    const bufferSize = this.ctx.sampleRate * 0.5;
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    const source = this.ctx.createBufferSource();
    source.buffer = buffer;
    const filter = this.ctx.createBiquadFilter();
    filter.type = "bandpass";
    filter.frequency.value = 600;
    filter.Q.value = 2;
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.15, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.5);
    source.connect(filter);
    filter.connect(gain);
    gain.connect(this.master);
    source.start(this.ctx.currentTime);
  }

  playTempZero() {
    // Freeze shatter
    this._playSweep(1200, 60, 0.4, "sawtooth", 0.25);
    this._playNoise(0.3, 0.2);
  }

  playCountdown() {
    this._playTone(440, 0.1, "square", 0.2);
  }

  playCountdownGo() {
    this._playTone(880, 0.2, "square", 0.25);
  }

  playRoundEnd() {
    this._playTone(330, 0.15, "square", 0.2);
    const t = setTimeout(() => this._playTone(440, 0.2, "square", 0.2), 150);
    this._timers.push(t);
  }

  playVictory() {
    // Arctic fanfare
    const notes = [523, 659, 784, 1047];
    notes.forEach((freq, i) => {
      const t = setTimeout(() => this._playTone(freq, 0.2, "square", 0.2), i * 150);
      this._timers.push(t);
    });
  }

  playGameOver() {
    this._playSweep(440, 110, 0.5, "sawtooth", 0.2);
  }

  // ── Ambient wind drone ───────────────────────────────────────

  startAmbientWind() {
    if (!this.ctx || this._windOsc) return;
    this._windOsc = this.ctx.createOscillator();
    this._windGain = this.ctx.createGain();
    this._windOsc.type = "sine";
    this._windOsc.frequency.value = 80;
    this._windGain.gain.value = 0.03;
    this._windOsc.connect(this._windGain);
    this._windGain.connect(this.master);
    this._windOsc.start();
  }

  stopAmbientWind() {
    if (this._windOsc) {
      try {
        this._windOsc.stop();
      } catch {
        /* already stopped */
      }
      this._windOsc = null;
      this._windGain = null;
    }
  }

  // ── Cleanup ──────────────────────────────────────────────────

  destroy() {
    this.stopAmbientWind();
    this._timers.forEach(clearTimeout);
    this._timers = [];
    if (this.ctx && this.ctx.state !== "closed") {
      try {
        this.ctx.close();
      } catch {
        /* ignore */
      }
    }
  }
}
