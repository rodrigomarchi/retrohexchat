import { FullscreenToggleController } from "../../lib/fullscreen.js";

/**
 * The full-screen key of a Retro Game's menu: it presents the whole stage —
 * the game, its pad and the menu over it — fullscreen (`lib/fullscreen.js`).
 * The key lives in the menu, so the hook is on the key and finds its stage by
 * `data-stage` (the stage's id).
 */
export function createStageFullscreenHook({
  fullscreenFactory = (options) => new FullscreenToggleController(options),
} = {}) {
  return {
    mounted() {
      const target = document.getElementById(this.el.dataset.stage);
      this.fullscreen = fullscreenFactory({ button: this.el, target });
      this.fullscreen.attach();
    },

    destroyed() {
      this.fullscreen?.detach();
      this.fullscreen = null;
    },
  };
}

export default createStageFullscreenHook();
