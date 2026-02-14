/**
 * Sound catalog and synthesis.
 *
 * Extracted from: sound_hook.js
 */

export const SOUND_CATALOG = {
  none: null,
  beep: { frequency: 520, duration: 0.1, volume: 0.2, waveType: "sine" },
  ding_low: { frequency: 440, duration: 0.15, volume: 0.2, waveType: "sine" },
  ding_high: { frequency: 880, duration: 0.15, volume: 0.25, waveType: "sine" },
  chime_short: { frequency: 660, duration: 0.12, volume: 0.2, waveType: "sine" },
  chime_long: { frequency: 660, duration: 0.3, volume: 0.2, waveType: "sine" },
  chime_high: { frequency: 880, duration: 0.25, volume: 0.25, waveType: "sine" },
  chime_low: { frequency: 330, duration: 0.25, volume: 0.2, waveType: "sine" },
  alert: { frequency: 880, duration: 0.3, volume: 0.35, waveType: "square" },
  buzz: { frequency: 220, duration: 0.2, volume: 0.2, waveType: "sawtooth" },
  click: { frequency: 1200, duration: 0.05, volume: 0.15, waveType: "square" },
  ring: { frequency: 740, duration: 0.4, volume: 0.25, waveType: "sine" },
  notify: { frequency: 600, duration: 0.15, volume: 0.2, waveType: "triangle" },
  blip: { frequency: 480, duration: 0.08, volume: 0.15, waveType: "sine" },
  whoosh: { frequency: 300, duration: 0.25, volume: 0.15, waveType: "triangle" },
};

/**
 * Synthesize and play a sound by name.
 *
 * @param {AudioContext} audioCtx - An AudioContext instance
 * @param {string} name - Sound name from SOUND_CATALOG
 */
export function synthesizeSound(audioCtx, name) {
  const config = SOUND_CATALOG[name];
  if (!config) return;

  try {
    const oscillator = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();

    oscillator.connect(gainNode);
    gainNode.connect(audioCtx.destination);

    oscillator.type = config.waveType;
    oscillator.frequency.setValueAtTime(config.frequency, audioCtx.currentTime);
    gainNode.gain.setValueAtTime(config.volume, audioCtx.currentTime);
    gainNode.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + config.duration);

    oscillator.start(audioCtx.currentTime);
    oscillator.stop(audioCtx.currentTime + config.duration);
  } catch {
    // Audio not available
  }
}
