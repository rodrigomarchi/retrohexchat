/**
 * LiveView binding for the RetroTable component.
 *
 * All behaviour lives in `lib/ui/retro_table.js`, which knows nothing about
 * LiveView — see that module for the `data-retro-table-*` contract and the
 * client-owned state (column widths, hidden columns, selection) it re-asserts
 * after every server patch. Nothing here round-trips to the server: ordering
 * and pagination arrive as fresh markup, and `reconcile()` puts the local
 * layout back on top.
 *
 * Mounted on the `.retro-table` container rendered by the RetroTable component.
 */
import { createRetroTable } from "../../lib/ui/retro_table";

export function createRetroTableHook({ tableFactory = createRetroTable } = {}) {
  return {
    mounted() {
      this.table = tableFactory(this.el);
      this.table.mount();
    },

    updated() {
      this.table.reconcile();
    },

    destroyed() {
      this.table.destroy();
    },
  };
}

export default createRetroTableHook();
