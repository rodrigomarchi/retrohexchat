/**
 * Hex Hockey — Web Audio API synthesizer.
 *
 * All sounds are generated procedurally. Zero external dependencies.
 * Cyberpunk arena aesthetic: sharp slaps, deep horns, metallic impacts.
 */

export class HexHockeyAudio {
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
    this._droneOsc = null;
    this._droneGain = null;
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
    const bufferSize = Math.round(this.ctx.sampleRate * duration);
    const buffer = this.ctx.createBuffer(1, bufferSize, this.ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * volume;
    }
    const src = this.ctx.createBufferSource();
    src.buffer = buffer;
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(volume, this.ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + duration);
    src.connect(gain);
    gain.connect(this.master);
    src.start(this.ctx.currentTime);
  }

  // ── Game sounds ──────────────────────────────────────────────

  /** Sharp slap — puck shot */
  playShot() {
    this._playNoise(0.06, 0.4);
    this._playTone(800, 0.05, "square", 0.25);
  }

  /** Thud — puck hits wall */
  playWallBounce() {
    this._playTone(120, 0.1, "triangle", 0.3);
    this._playNoise(0.04, 0.15);
  }

  /** Deeper thud — goalie blocks puck */
  playGoalieBlock() {
    this._playTone(80, 0.15, "triangle", 0.35);
    this._playNoise(0.06, 0.2);
  }

  /** Hockey horn/siren — GOAL! */
  playGoal() {
    if (!this.ctx) return;

    // Horn blast (ascending)
    const t = this.ctx.currentTime;
    const osc1 = this.ctx.createOscillator();
    const osc2 = this.ctx.createOscillator();
    const gain = this.ctx.createGain();

    osc1.type = "sawtooth";
    osc1.frequency.setValueAtTime(200, t);
    osc1.frequency.linearRampToValueAtTime(400, t + 0.3);
    osc1.frequency.setValueAtTime(400, t + 0.3);
    osc1.frequency.linearRampToValueAtTime(200, t + 0.6);

    osc2.type = "square";
    osc2.frequency.setValueAtTime(204, t);
    osc2.frequency.linearRampToValueAtTime(404, t + 0.3);
    osc2.frequency.setValueAtTime(404, t + 0.3);
    osc2.frequency.linearRampToValueAtTime(204, t + 0.6);

    gain.gain.setValueAtTime(0.25, t);
    gain.gain.setValueAtTime(0.25, t + 0.5);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.8);

    osc1.connect(gain);
    osc2.connect(gain);
    gain.connect(this.master);
    osc1.start(t);
    osc2.start(t);
    osc1.stop(t + 0.8);
    osc2.stop(t + 0.8);

    // Crowd cheer (noise burst)
    const id = setTimeout(() => {
      this._playNoise(0.4, 0.12);
    }, 200);
    this._timers.push(id);
  }

  /** Impact — successful tackle */
  playTackleSuccess() {
    this._playTone(150, 0.08, "square", 0.3);
    this._playNoise(0.05, 0.25);
  }

  /** Stumble — failed tackle */
  playTackleFail() {
    this._playSweep(300, 100, 0.2, "triangle", 0.2);
  }

  /** Short whistle — face-off */
  playFaceoffWhistle() {
    this._playTone(1200, 0.15, "sine", 0.2);
    const id = setTimeout(() => {
      this._playTone(1200, 0.08, "sine", 0.15);
    }, 180);
    this._timers.push(id);
  }

  /** Long buzzer — period end */
  playPeriodBuzzer() {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.value = 180;
    gain.gain.setValueAtTime(0.3, t);
    gain.gain.setValueAtTime(0.3, t + 0.6);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 1.0);
    osc.connect(gain);
    gain.connect(this.master);
    osc.start(t);
    osc.stop(t + 1.0);
  }

  /** Tension drone — sudden death */
  playSuddenDeath() {
    if (!this.ctx || this._droneOsc) return;
    const osc = this.ctx.createOscillator();
    const gain = this.ctx.createGain();
    osc.type = "sine";
    osc.frequency.value = 55;
    gain.gain.value = 0.08;
    osc.connect(gain);
    gain.connect(this.master);
    osc.start();
    this._droneOsc = osc;
    this._droneGain = gain;
  }

  /** Stop tension drone */
  stopSuddenDeath() {
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

  /** Victory fanfare */
  playVictory() {
    this.stopSuddenDeath();
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const notes = [523, 659, 784, 1047]; // C5, E5, G5, C6
    notes.forEach((freq, i) => {
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = "square";
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.2, t + i * 0.15);
      gain.gain.exponentialRampToValueAtTime(0.001, t + i * 0.15 + 0.3);
      osc.connect(gain);
      gain.connect(this.master);
      osc.start(t + i * 0.15);
      osc.stop(t + i * 0.15 + 0.3);
    });
  }

  /** Click — puck capture */
  playCapture() {
    this._playTone(600, 0.03, "square", 0.15);
  }

  /** Countdown tick */
  playCountdownTick() {
    this._playTone(880, 0.08, "sine", 0.2);
  }

  /** GO! sound */
  playGo() {
    this._playTone(1320, 0.12, "square", 0.25);
  }

  /** Cleanup */
  destroy() {
    this.stopSuddenDeath();
    for (const id of this._timers) clearTimeout(id);
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
