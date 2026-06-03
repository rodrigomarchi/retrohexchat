import { describe, expect, it, vi } from "vitest";

import { lazyFeatureHook } from "../../js/hooks/lazy_feature_hook.js";

function buildHook(loader, overrides = {}) {
  return Object.create(
    lazyFeatureHook({
      name: "TestLazyHook",
      loader,
      reason: "Test feature boundary.",
      ...overrides,
    }),
  );
}

describe("lazyFeatureHook", () => {
  it("loads and delegates lifecycle callbacks to the implementation", async () => {
    const implementation = {
      mounted: vi.fn(function () {
        this.loaded = true;
      }),
      updated: vi.fn(),
      destroyed: vi.fn(),
    };
    const hook = buildHook(() => Promise.resolve({ default: implementation }));

    hook.mounted();
    await hook.__lazyFeaturePromise;
    hook.updated("payload");
    hook.destroyed();

    expect(hook.loaded).toBe(true);
    expect(hook.__lazyFeatureName).toBe("TestLazyHook");
    expect(implementation.mounted).toHaveBeenCalledOnce();
    expect(implementation.updated).toHaveBeenCalledWith("payload");
    expect(implementation.destroyed).toHaveBeenCalledOnce();
  });

  it("attaches implementation helper methods before mounted runs", async () => {
    const implementation = {
      mounted: vi.fn(function () {
        this._wireControls("ready");
      }),
      _wireControls: vi.fn(function (state) {
        this.wiredState = state;
      }),
    };
    const hook = buildHook(() => Promise.resolve({ default: implementation }));

    hook.mounted();
    await hook.__lazyFeaturePromise;

    expect(implementation._wireControls).toHaveBeenCalledWith("ready");
    expect(hook.wiredState).toBe("ready");
  });

  it("does not mount the implementation after the facade is destroyed", async () => {
    const implementation = { mounted: vi.fn() };
    const hook = buildHook(() => Promise.resolve({ default: implementation }));

    hook.mounted();
    hook.destroyed();
    await hook.__lazyFeaturePromise;

    expect(implementation.mounted).not.toHaveBeenCalled();
    expect(hook.__lazyFeatureImplementation).toBeUndefined();
  });

  it("requires a metadata object", () => {
    expect(() => lazyFeatureHook()).toThrow("configuration object");
  });

  it("requires name, loader, and reason", () => {
    expect(() => lazyFeatureHook({ loader: () => Promise.resolve(), reason: "x" })).toThrow(
      "non-empty name",
    );
    expect(() => lazyFeatureHook({ name: "MissingLoader", reason: "x" })).toThrow(
      "loader function",
    );
    expect(() =>
      lazyFeatureHook({ name: "MissingReason", loader: () => Promise.resolve() }),
    ).toThrow("requires a reason");
  });

  it("requires readyEvent when server events are declared", () => {
    expect(() =>
      lazyFeatureHook({
        name: "ServerEventHook",
        loader: () => Promise.resolve({ default: {} }),
        reason: "Server-pushed lazy feature.",
        serverEvents: ["feature_start"],
      }),
    ).toThrow("must declare readyEvent");
  });

  it("rejects safeWithoutReady exceptions", () => {
    expect(() =>
      lazyFeatureHook({
        name: "SafeWithoutReadyHook",
        loader: () => Promise.resolve({ default: {} }),
        reason: "Server-pushed lazy feature.",
        serverEvents: ["feature_start"],
        safeWithoutReady: true,
      }),
    ).toThrow("does not support safeWithoutReady");
  });

  it("exposes metadata for contract tooling", () => {
    const facade = lazyFeatureHook({
      name: "ReadyHook",
      loader: () => Promise.resolve({ default: {} }),
      reason: "Server-pushed lazy feature.",
      serverEvents: ["feature_start"],
      readyEvent: "feature_ready",
    });

    expect(facade.__lazyFeature).toEqual({
      name: "ReadyHook",
      serverEvents: ["feature_start"],
      readyEvent: "feature_ready",
      reason: "Server-pushed lazy feature.",
    });
  });
});
