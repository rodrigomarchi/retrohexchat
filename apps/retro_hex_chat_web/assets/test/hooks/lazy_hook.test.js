import { describe, expect, it, vi } from "vitest";

import { lazyHook } from "../../js/hooks/lazy_hook.js";

describe("lazyHook", () => {
  it("loads and delegates lifecycle callbacks to the implementation", async () => {
    const implementation = {
      mounted: vi.fn(function () {
        this.loaded = true;
      }),
      updated: vi.fn(),
      destroyed: vi.fn(),
    };
    const hook = Object.create(lazyHook(() => Promise.resolve({ default: implementation })));

    hook.mounted();
    await hook.__lazyHookPromise;
    hook.updated("payload");
    hook.destroyed();

    expect(hook.loaded).toBe(true);
    expect(implementation.mounted).toHaveBeenCalledOnce();
    expect(implementation.updated).toHaveBeenCalledWith("payload");
    expect(implementation.destroyed).toHaveBeenCalledOnce();
  });

  it("does not mount the implementation after the facade is destroyed", async () => {
    const implementation = { mounted: vi.fn() };
    const hook = Object.create(lazyHook(() => Promise.resolve({ default: implementation })));

    hook.mounted();
    hook.destroyed();
    await hook.__lazyHookPromise;

    expect(implementation.mounted).not.toHaveBeenCalled();
    expect(hook.__lazyHookImplementation).toBeUndefined();
  });
});
