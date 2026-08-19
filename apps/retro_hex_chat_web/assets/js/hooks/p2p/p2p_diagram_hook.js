/**
 * LiveView binding for the P2P connection diagram.
 *
 * The RAF loop, the dot elements and the per-frame maths live in
 * `lib/p2p/diagram.js`; this reads the dataset the Elixir component renders and
 * lets the animator sync on mount and update. Heavy animation stays CSS-only.
 */
import { createDiagramAnimator } from "../../lib/p2p/diagram.js";

export function createP2PDiagramHook({ factory = createDiagramAnimator } = {}) {
  return {
    mounted() {
      this.animator = factory(this.el);
      this.animator.sync();
    },

    updated() {
      this.animator.sync();
    },

    destroyed() {
      this.animator.stop();
    },
  };
}

export default createP2PDiagramHook();
