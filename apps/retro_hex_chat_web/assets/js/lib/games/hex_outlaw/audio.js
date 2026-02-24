/**
 * Web Audio API synthesized sound effects for Hex Outlaw.
 * All sounds are generated procedurally — no sample files.
 * Western cyberpunk aesthetic: gunshots, ricochets, church bells.
 * @module games/hex_outlaw_audio
 */

export class OutlawAudio {
  constructor() {
    /** @type {AudioContext|null} */
    this._ctx = null;
  }

  /**
   * Close the AudioContext and release resources.
   */
  dispose() {
    if (this._ctx) {
      this._ctx.close().catch(() => {});
      this._ctx = null;
    }
  }

  /**
   * Lazily create or resume AudioContext (browser autoplay policy).
   * @returns {AudioContext}
   */
  _ensureContext() {
    if (!this._ctx) {
      this._ctx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (this._ctx.state === "suspended") {
      this._ctx.resume().catch(() => {});
    }
    return this._ctx;
  }

  /**
   * Gunshot — short explosive bang with low thud.
   */
  playGunshot() {
    const ctx = this._ensureContext();
    const t = ctx.currentTime;

    // White noise burst for the crack
    const bufferSize = ctx.sampleRate * 0.08;
    const noiseBuffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
    const data = noiseBuffer.getChannelData(0);
    for (let i = 0; i < bufferSize; i++) {
      data[i] = (Math.random() * 2 - 1) * (1 - i / bufferSize);
    }
    const noise = ctx.createBufferSource();
    noise.buffer = noiseBuffer;
    const noiseGain = ctx.createGain();
    noiseGain.gain.setValueAtTime(0.15, t);
    noiseGain.gain.linearRampToValueAtTime(0, t + 0.08);
    noise.connect(noiseGain).connect(ctx.destination);
    noise.start(t);
    noise.stop(t + 0.08);

    // Low thud for body
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(150, t);
    osc.frequency.linearRampToValueAtTime(60, t + 0.12);
    gain.gain.setValueAtTime(0.12, t);
    gain.gain.linearRampToValueAtTime(0, t + 0.12);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.12);
  }

  /**
   * Ricochet — metallic ping ascending.
   */
  playRicochet() {
    const ctx = this._ensureContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(2000, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(3200, ctx.currentTime + 0.1);
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.1);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.1);
  }

  /**
   * Hit opponent — impact thud + metallic sting.
   */
  playHit() {
    const ctx = this._ensureContext();
    const t = ctx.currentTime;

    // Impact thud
    const osc1 = ctx.createOscillator();
    const gain1 = ctx.createGain();
    osc1.type = "sawtooth";
    osc1.frequency.setValueAtTime(300, t);
    osc1.frequency.linearRampToValueAtTime(80, t + 0.2);
    gain1.gain.setValueAtTime(0.18, t);
    gain1.gain.linearRampToValueAtTime(0, t + 0.2);
    osc1.connect(gain1).connect(ctx.destination);
    osc1.start(t);
    osc1.stop(t + 0.2);

    // Metallic ricochet sting
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(1500, t);
    osc2.frequency.linearRampToValueAtTime(800, t + 0.15);
    gain2.gain.setValueAtTime(0.08, t);
    gain2.gain.linearRampToValueAtTime(0, t + 0.15);
    osc2.connect(gain2).connect(ctx.destination);
    osc2.start(t);
    osc2.stop(t + 0.15);
  }

  /**
   * Bullet hits obstacle — dry thud.
   */
  playObstacleHit() {
    const ctx = this._ensureContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(150, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(60, ctx.currentTime + 0.1);
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.1);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.1);
  }

  /**
   * Western church bell — round start.
   */
  playBell() {
    const ctx = this._ensureContext();
    const t = ctx.currentTime;

    // Main bell tone
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sine";
    osc.frequency.setValueAtTime(600, t);
    gain.gain.setValueAtTime(0.15, t);
    gain.gain.exponentialRampToValueAtTime(0.001, t + 0.8);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t);
    osc.stop(t + 0.8);

    // Overtone
    const osc2 = ctx.createOscillator();
    const gain2 = ctx.createGain();
    osc2.type = "sine";
    osc2.frequency.setValueAtTime(1200, t);
    gain2.gain.setValueAtTime(0.06, t);
    gain2.gain.exponentialRampToValueAtTime(0.001, t + 0.5);
    osc2.connect(gain2).connect(ctx.destination);
    osc2.start(t);
    osc2.stop(t + 0.5);
  }

  /**
   * Countdown tick.
   */
  playCountdown() {
    const ctx = this._ensureContext();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "square";
    osc.frequency.setValueAtTime(500, ctx.currentTime);
    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.08);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.08);
  }

  /**
   * Win — harmonica western arpeggio (D-F#-A-D).
   */
  playWin() {
    const ctx = this._ensureContext();
    const notes = [294, 370, 440, 587]; // D4, F#4, A4, D5
    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "triangle";
      osc.frequency.setValueAtTime(freq, ctx.currentTime + i * 0.15);
      gain.gain.setValueAtTime(0.1, ctx.currentTime + i * 0.15);
      gain.gain.linearRampToValueAtTime(0, ctx.currentTime + i * 0.15 + 0.15);
      osc.connect(gain).connect(ctx.destination);
      osc.start(ctx.currentTime + i * 0.15);
      osc.stop(ctx.currentTime + i * 0.15 + 0.15);
    });
  }

  /**
   * Lose — descending sawtooth.
   */
  playLose() {
    const ctx = this._ensureContext();
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
}
