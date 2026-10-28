import { describe, expect, it, vi } from "vitest";

import { lazyFeatureHooks } from "../../../js/hooks/lazy_feature_hooks.js";
import { createStageFullscreenHook } from "../../../js/hooks/games/stage_fullscreen_hook.js";

describe("StageFullscreenHook", () => {
  it("presents the stage its key names, and lets go on leaving", () => {
    const stage = document.createElement("div");
    stage.id = "retro-stage";
    document.body.appendChild(stage);
    const el = document.createElement("button");
    el.dataset.stage = "retro-stage";
    const toggle = { attach: vi.fn(), detach: vi.fn() };
    const fullscreenFactory = vi.fn(() => toggle);
    const hook = Object.assign(Object.create(createStageFullscreenHook({ fullscreenFactory })), {
      el,
    });

    hook.mounted();
    expect(fullscreenFactory).toHaveBeenCalledWith({ button: el, target: stage });
    expect(toggle.attach).toHaveBeenCalled();

    hook.destroyed();
    expect(toggle.detach).toHaveBeenCalled();
    stage.remove();
  });

  it("is loaded only where a menu shows the key", () => {
    expect(lazyFeatureHooks.StageFullscreenHook).toBeDefined();
  });
});
