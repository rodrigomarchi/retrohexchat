/**
 * LiveView hook for notification sounds.
 *
 * Uses the Web Audio API to generate short synthesized tones.
 * Supports a catalog of 14 named sounds plus "none".
 * Respects a mute setting stored in localStorage.
 */
import { SOUND_CATALOG, synthesizeSound } from "../lib/sound.js";

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
    if (!SOUND_CATALOG[name]) return;
    synthesizeSound(this.getAudioContext(), name);
  },
};

export default SoundHook;
