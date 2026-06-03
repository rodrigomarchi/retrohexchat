const LIFECYCLE_CALLBACKS = ["beforeUpdate", "updated", "destroyed", "disconnected", "reconnected"];

export function lazyFeatureHook(options) {
  const config = validateConfig(options);
  const hook = {
    __lazyFeature: {
      name: config.name,
      serverEvents: config.serverEvents,
      readyEvent: config.readyEvent,
      reason: config.reason,
    },

    mounted() {
      this.__lazyFeatureActive = true;
      this.__lazyFeatureName = config.name;
      this.__lazyFeaturePromise = config.loader().then((module) => {
        if (!this.__lazyFeatureActive) return null;

        const implementation = module.default;
        this.__lazyFeatureImplementation = implementation;
        attachImplementationMethods(this, implementation);
        implementation?.mounted?.call(this);
        return implementation;
      });
    },
  };

  for (const callback of LIFECYCLE_CALLBACKS) {
    hook[callback] = function (...args) {
      if (callback === "destroyed") {
        this.__lazyFeatureActive = false;
      }

      this.__lazyFeatureImplementation?.[callback]?.call(this, ...args);
    };
  }

  return hook;
}

function validateConfig(options) {
  if (!options || typeof options !== "object") {
    throw new Error("lazyFeatureHook requires a configuration object.");
  }

  const { name, loader, serverEvents = [], readyEvent = null, reason } = options;

  if (!isNonEmptyString(name)) {
    throw new Error("lazyFeatureHook requires a non-empty name.");
  }

  if (typeof loader !== "function") {
    throw new Error(`lazyFeatureHook(${name}) requires a loader function.`);
  }

  if (!isNonEmptyString(reason)) {
    throw new Error(`lazyFeatureHook(${name}) requires a reason.`);
  }

  if (!Array.isArray(serverEvents) || serverEvents.some((event) => !isNonEmptyString(event))) {
    throw new Error(`lazyFeatureHook(${name}) serverEvents must be an array of event names.`);
  }

  if (readyEvent !== null && !isNonEmptyString(readyEvent)) {
    throw new Error(`lazyFeatureHook(${name}) readyEvent must be a non-empty string when set.`);
  }

  if ("safeWithoutReady" in options || "safeWithoutReadyReason" in options) {
    throw new Error(
      `lazyFeatureHook(${name}) does not support safeWithoutReady; declare readyEvent for server events.`,
    );
  }

  if (serverEvents.length > 0 && !readyEvent) {
    throw new Error(`lazyFeatureHook(${name}) handles serverEvents and must declare readyEvent.`);
  }

  return {
    name,
    loader,
    serverEvents,
    readyEvent,
    reason,
  };
}

function attachImplementationMethods(hook, implementation) {
  for (const [key, value] of Object.entries(implementation || {})) {
    if (key === "mounted" || key in hook || typeof value !== "function") {
      continue;
    }

    hook[key] = value;
  }
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}
