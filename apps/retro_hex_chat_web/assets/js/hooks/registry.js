import { criticalHooks } from "./critical_hooks";
import { lazyFeatureHooks } from "./lazy_feature_hooks";

export {
  preserveScrollBeforeElUpdated,
  preserveScrollPatchEnd,
  preserveScrollPatchStart,
} from "./ui/preserve_scroll_hook";

export function buildHooks() {
  return {
    ...criticalHooks,
    ...lazyFeatureHooks,
  };
}
