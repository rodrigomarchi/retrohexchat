/**
 * LiveView hook for notification sounds.
 *
 * Uses the Web Audio API to generate short synthesized tones.
 * Supports a catalog of 14 named sounds plus "none".
 * Respects a mute setting stored in localStorage.
 */

const SOUND_CATALOG = {
  none:        null,
  beep:        { frequency: 520, duration: 0.1, volume: 0.2, waveType: "sine" },
  ding_low:    { frequency: 440, duration: 0.15, volume: 0.2, waveType: "sine" },
  ding_high:   { frequency: 880, duration: 0.15, volume: 0.25, waveType: "sine" },
  chime_short: { frequency: 660, duration: 0.12, volume: 0.2, waveType: "sine" },
  chime_long:  { frequency: 660, duration: 0.3, volume: 0.2, waveType: "sine" },
  chime_high:  { frequency: 880, duration: 0.25, volume: 0.25, waveType: "sine" },
  chime_low:   { frequency: 330, duration: 0.25, volume: 0.2, waveType: "sine" },
  alert:       { frequency: 880, duration: 0.3, volume: 0.35, waveType: "square" },
  buzz:        { frequency: 220, duration: 0.2, volume: 0.2, waveType: "sawtooth" },
  click:       { frequency: 1200, duration: 0.05, volume: 0.15, waveType: "square" },
  ring:        { frequency: 740, duration: 0.4, volume: 0.25, waveType: "sine" },
  notify:      { frequency: 600, duration: 0.15, volume: 0.2, waveType: "triangle" },
  blip:        { frequency: 480, duration: 0.08, volume: 0.15, waveType: "sine" },
  whoosh:      { frequency: 300, duration: 0.25, volume: 0.15, waveType: "triangle" },
};

const SoundHook = {
  mounted() {
    this.audioCtx = null;
    this.muted = localStorage.getItem("retro_hex_chat_mute") === "true";

    this.pushEvent("mute_state_sync", { muted: this.muted });

    this.handleEvent("play_sound", ({ type }) => {
      if (!this.muted) {
        this.playSound(type);
      }
    });

    this.handleEvent("toggle_mute", () => {
      this.muted = !this.muted;
      localStorage.setItem("retro_hex_chat_mute", this.muted.toString());
    });
  },

  getAudioContext() {
    if (!this.audioCtx) {
      this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    return this.audioCtx;
  },

  playSound(name) {
    const config = SOUND_CATALOG[name];
    if (!config) return;

    try {
      const ctx = this.getAudioContext();
      const oscillator = ctx.createOscillator();
      const gainNode = ctx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      oscillator.type = config.waveType;
      oscillator.frequency.setValueAtTime(config.frequency, ctx.currentTime);
      gainNode.gain.setValueAtTime(config.volume, ctx.currentTime);
      gainNode.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + config.duration);

      oscillator.start(ctx.currentTime);
      oscillator.stop(ctx.currentTime + config.duration);
    } catch (_e) {
      // Audio not available, silently ignore
    }
  },
};

export default SoundHook;
