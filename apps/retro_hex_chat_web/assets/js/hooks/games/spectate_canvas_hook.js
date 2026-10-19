/**
 * LiveView Hook: SpectateCanvasHook
 *
 * Binds a watched match's canvas to the spectator view; everything it does is
 * the view's (`lib/games/spectator_view.js`).
 */
import { createSpectatorView } from "../../lib/games/spectator_view.js";

export function createSpectateCanvasHook(deps = {}) {
  return {
    mounted() {
      this.view = createSpectatorView(this.el, deps);
      this.view.mount();
    },

    destroyed() {
      this.view?.destroy();
    },
  };
}

export default createSpectateCanvasHook();
