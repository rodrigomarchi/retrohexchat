/**
 * LiveView hook for notification sounds.
 *
 * Uses the Web Audio API to generate short beep tones.
 * Respects a mute setting stored in localStorage.
 */
const SoundHook = {
  mounted() {
    this.audioCtx = null;
    this.muted = localStorage.getItem("retro_hex_chat_mute") === "true";

    this.handleEvent("play_sound", ({ type }) => {
      if (!this.muted) {
        this.playBeep(type);
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

  playBeep(type) {
    try {
      const ctx = this.getAudioContext();
      const oscillator = ctx.createOscillator();
      const gainNode = ctx.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(ctx.destination);

      const config = this.getSoundConfig(type);

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

  getSoundConfig(type) {
    switch (type) {
      case "mention":
        return { frequency: 880, duration: 0.15, volume: 0.3, waveType: "sine" };
      case "pm":
        return { frequency: 660, duration: 0.2, volume: 0.25, waveType: "sine" };
      case "join":
        return { frequency: 440, duration: 0.1, volume: 0.15, waveType: "triangle" };
      case "error":
        return { frequency: 220, duration: 0.3, volume: 0.2, waveType: "square" };
      default:
        return { frequency: 520, duration: 0.1, volume: 0.2, waveType: "sine" };
    }
  },
};

export default SoundHook;
