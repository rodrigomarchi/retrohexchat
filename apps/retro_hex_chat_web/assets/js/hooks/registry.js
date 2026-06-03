import { criticalHooks } from "./critical_hooks";
import { lazyFeatureHooks } from "./lazy_feature_hooks";

export function buildHooks() {
  return {
    ...criticalHooks,
    ...lazyFeatureHooks,
  };
}
