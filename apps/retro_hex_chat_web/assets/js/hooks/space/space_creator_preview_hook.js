/**
 * LiveView binding for the character creator's preview: creates the
 * `lib/space/creator_preview.js` controller and tells it when the recipe the
 * LiveView renders has changed.
 */
import { loadCharacters } from "../../lib/space/character_loader.js";
import { createCreatorPreview } from "../../lib/space/creator_preview.js";

export function createSpaceCreatorPreviewHook({ factory = createCreatorPreview } = {}) {
  return {
    mounted() {
      this.preview = factory(this.el, { load: (url) => loadCharacters(url) });
    },

    updated() {
      this.preview?.update();
    },

    destroyed() {
      this.preview?.destroy();
    },
  };
}

export default createSpaceCreatorPreviewHook();
