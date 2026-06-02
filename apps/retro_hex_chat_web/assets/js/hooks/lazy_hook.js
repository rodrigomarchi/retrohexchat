const LIFECYCLE_CALLBACKS = ["beforeUpdate", "updated", "destroyed", "disconnected", "reconnected"];

export function lazyHook(loader) {
  const hook = {
    mounted() {
      this.__lazyHookActive = true;
      this.__lazyHookPromise = loader().then((module) => {
        if (!this.__lazyHookActive) return null;

        const implementation = module.default;
        this.__lazyHookImplementation = implementation;
        implementation?.mounted?.call(this);
        return implementation;
      });
    },
  };

  for (const callback of LIFECYCLE_CALLBACKS) {
    hook[callback] = function (...args) {
      if (callback === "destroyed") {
        this.__lazyHookActive = false;
      }

      this.__lazyHookImplementation?.[callback]?.call(this, ...args);
    };
  }

  return hook;
}
