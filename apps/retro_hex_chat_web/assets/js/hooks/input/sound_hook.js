/**
 * LiveView hook for notification sounds.
 *
 * Plays the catalog's synthesized tones (lib/input/sound.js) when the server
 * asks, unless the server-rendered mute setting is on.
 */
import { createNotificationSounds } from "../../lib/input/sound.js";

const SoundHook = {
  mounted() {
    this.sounds = createNotificationSounds();
    this.syncMutedFromDataset();

    this.handleEvent("play_sound", ({ type }) => {
      if (!this.muted) {
        this.sounds.play(type);
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

  destroyed() {
    this.sounds.dispose();
  },

  syncMutedFromDataset() {
    this.muted = this.el.dataset.muted === "true";
  },
};

export default SoundHook;
