import { applyHead } from "../../lib/site/head_sync";

/**
 * HeadSync — applies the head the server names for the window in front
 * (`lib/site/head_sync.js`). Mounted on a small hidden element of its own.
 */
const HeadSyncHook = {
  mounted() {
    this.handleEvent("head:sync", (head) => applyHead(document, head));
  },
};

export default HeadSyncHook;
