/**
 * LiveView binding for collapsible toolbar groups.
 *
 * All behaviour lives in `lib/ui/toolbar_group.js`, which knows nothing about
 * LiveView — see that module for the `data-toolbar-group-toggle` /
 * `.toolbar-group-dropdown` contract.
 */
import { createToolbarGroup } from "../../lib/ui/toolbar_group.js";

export function createToolbarGroupHook({ factory = createToolbarGroup } = {}) {
  return {
    mounted() {
      this.group = factory(this.el);
      this.group.mount();
    },

    destroyed() {
      this.group.destroy();
    },
  };
}

export default createToolbarGroupHook();
