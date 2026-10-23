/**
 * Synth sound effects for Block Breakers — cyberpunk cooperative aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/breakout_audio
 */

import { GameSynth } from "../synth.js";

export class BreakoutAudio extends GameSynth {
  /** Paddle hit — 600Hz triangle, 50ms. */
  playPaddleHit() {
    this._playTone(600, 0.05, "triangle", 0.15);
  }

  /** Wall bounce — 300Hz square, 30ms. */
  playWallBounce() {
    this._playTone(300, 0.03, "square", 0.1);
  }

  /**
   * Block hit — pitch varies by row (higher rows = higher pitch).
   * @param {number} row - 0 (top) to 4 (bottom)
   */
  playBlockHit(row) {
    const baseFreq = 800;
    const freq = baseFreq + (4 - row) * 100; // Row 0 = 1200Hz, Row 4 = 800Hz
    this._playTone(freq, 0.04, "sawtooth", 0.12);
  }

  /** Life lost — descending 400->100Hz sawtooth, 400ms. */
  playLifeLost() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(400, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(100, ctx.currentTime + 0.4);
    gain.gain.setValueAtTime(0.15, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.4);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.4);
  }

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Win — ascending arpeggio C-E-G-C (triumphant). */
  playWin() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [523, 659, 784, 1047]; // C5-E5-G5-C6
    const noteLen = 0.15;

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

  /** Lose — descending chromatic 500->200Hz, 600ms. */
  playLose() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(500, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(200, ctx.currentTime + 0.6);
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.6);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.6);
  }
}
