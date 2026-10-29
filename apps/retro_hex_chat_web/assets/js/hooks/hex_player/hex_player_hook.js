/**
 * LiveView binding for a Hex Player (`Components.UI.HexPlayer`): creates the
 * `lib/hex_player/player_controller.js` player on its root and lets it go
 * when the line that carries it leaves the page.
 */
import { createPlayer } from "../../lib/hex_player/player_controller.js";

export function createHexPlayerHook({ factory = createPlayer } = {}) {
  return {
    mounted() {
      this.player = factory(this.el, {
        // The root and the keys are the server's: an attribute set plainly
        // would be wiped by its next patch, so it goes through LiveView.
        mark: (element, name, value) => this.js().setAttribute(element, name, value),
      });
      this.player.mount();
    },

    destroyed() {
      this.player?.destroy();
    },
  };
}

export default createHexPlayerHook();
