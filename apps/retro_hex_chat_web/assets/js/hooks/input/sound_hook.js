/**
 * LiveView hook for notification sounds.
 *
 * Uses the Web Audio API to generate short synthesized tones.
 * Supports a catalog of 14 named sounds plus "none".
 * Respects the server-rendered mute setting.
 */
import { SOUND_CATALOG, synthesizeSound } from "../../lib/input/sound.js";

const SoundHook = {
  mounted() {
    this.audioCtx = null;
    this.syncMutedFromDataset();

    this.handleEvent("play_sound", ({ type }) => {
      if (!this.muted) {
        this.playSound(type);
      }
    });

    this.handleEvent("mute_state_changed", ({ muted }) => {
      if (typeof muted === "boolean") {
        this.muted = muted;
      }
    });
  },

  updated() {
    this.syncMutedFromDataset();
  },

  syncMutedFromDataset() {
    this.muted = this.el.dataset.muted === "true";
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
