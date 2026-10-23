/**
 * Synth sound effects for Light Trails — cyberpunk post-apocalyptic aesthetic.
 * Uses Web Audio API oscillators, zero external dependencies.
 * @module games/surround_audio
 */

import { GameSynth } from "../synth.js";

export class SurroundAudio extends GameSynth {
  /** Direction change — 200Hz square blip, 15ms, very low volume. */
  playMove() {
    this._playTone(200, 0.015, "square", 0.05);
  }

  /** Crash into trail/wall — descending 800->50Hz sawtooth sweep, 500ms. */
  playCrash() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(800, ctx.currentTime);
    osc.frequency.linearRampToValueAtTime(50, ctx.currentTime + 0.5);
    gain.gain.setValueAtTime(0.3, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0, ctx.currentTime + 0.5);
    osc.connect(gain).connect(ctx.destination);
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + 0.5);
  }

  /** Countdown tick — 600Hz square blip, 80ms. */
  playCountdown() {
    this._playTone(600, 0.08, "square", 0.12);
  }

  /** Round win — ascending C5->G5 two-note jingle. */
  playRoundWin() {
    const ctx = this._ensureContext();
    if (!ctx) return;
    const notes = [523, 784]; // C5, G5
    const noteLen = 0.1;

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

  /** Match win — ascending C-E-G-C-E arpeggio (triumphant). */
  playMatchWin() {
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

  /** Match lose — descending 500->150Hz sawtooth, 700ms. */
  playMatchLose() {
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
}
