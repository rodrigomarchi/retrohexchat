import { describe, expect, it, vi } from "vitest";

import { lazyFeatureHooks } from "../../../js/hooks/lazy_feature_hooks.js";
import { createRetroGamePadHook } from "../../../js/hooks/games/retro_game_pad_hook.js";

function mount(padFactory) {
  const el = document.createElement("div");
  const hook = Object.assign(Object.create(createRetroGamePadHook({ padFactory })), { el });
  hook.mounted();
  return { el, hook };
}

describe("RetroGamePadHook", () => {
  it("wires the pad under the game to keys the game reads, and lets go on leaving", () => {
    const pad = { attach: vi.fn(), detach: vi.fn() };
    const padFactory = vi.fn(() => pad);
    const { el, hook } = mount(padFactory);

    expect(padFactory).toHaveBeenCalledWith(expect.objectContaining({ root: el }));
    const { input } = padFactory.mock.calls[0][0];
    expect(typeof input.pressDirection).toBe("function");
    expect(typeof input.releaseAction).toBe("function");
    expect(pad.attach).toHaveBeenCalled();

    hook.destroyed();
    expect(pad.detach).toHaveBeenCalled();
  });

  it("is loaded only where a game shows its pad", () => {
    expect(lazyFeatureHooks.RetroGamePadHook).toBeDefined();
  });
});
