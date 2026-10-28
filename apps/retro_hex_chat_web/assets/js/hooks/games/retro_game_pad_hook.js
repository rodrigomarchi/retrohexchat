import { keyPadInput } from "../../lib/games/key_pad.js";
import { VirtualPadController } from "../../lib/virtual_pad.js";

/**
 * The pad under a Retro Game: its buttons press the keys the game reads
 * (`lib/games/key_pad.js`), through the pad every pad shares
 * (`lib/virtual_pad.js`).
 */
export function createRetroGamePadHook({
  padFactory = (options) => new VirtualPadController(options),
} = {}) {
  return {
    mounted() {
      this.pad = padFactory({ root: this.el, input: keyPadInput(window) });
      this.pad.attach();
    },

    destroyed() {
      this.pad?.detach();
      this.pad = null;
    },
  };
}

export default createRetroGamePadHook();
