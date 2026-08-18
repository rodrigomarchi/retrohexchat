import { criticalHooks } from "./critical_hooks";
import { lazyFeatureHooks } from "./lazy_feature_hooks";
import { scrollPreserver } from "../lib/ui/scroll_preservation";

// The morphdom callbacks the app wires into LiveSocket. They are not a hook —
// they coordinate scroll preservation across a patch cycle — so they live in
// lib/ui/scroll_preservation.js and are surfaced here under the names app.js
// already imports.
export const preserveScrollPatchStart = scrollPreserver.patchStart;
export const preserveScrollPatchEnd = scrollPreserver.patchEnd;
export const preserveScrollBeforeElUpdated = scrollPreserver.beforeElUpdated;

export function buildHooks() {
  return {
    ...criticalHooks,
    ...lazyFeatureHooks,
  };
}
