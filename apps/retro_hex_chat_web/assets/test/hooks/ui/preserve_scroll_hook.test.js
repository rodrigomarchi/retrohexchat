import { afterEach, describe, expect, it } from "vitest";

import PreserveScrollHook from "../../../js/hooks/ui/preserve_scroll_hook.js";
import { cleanupDOM, mountHook } from "../../helpers/hook_helper.js";

describe("PreserveScrollHook", () => {
  afterEach(() => {
    cleanupDOM();
  });

  it("restores the parent scroll position after a LiveView patch", () => {
    const parent = document.createElement("div");
    parent.scrollTop = 180;
    parent.scrollLeft = 12;
    document.body.appendChild(parent);

    const hook = mountHook(PreserveScrollHook, { parent });

    hook.beforeUpdate();
    parent.scrollTop = 0;
    parent.scrollLeft = 0;
    hook.updated();

    expect(parent.scrollTop).toBe(180);
    expect(parent.scrollLeft).toBe(12);
  });

  it("can preserve its own scroll position", () => {
    const hook = mountHook(PreserveScrollHook, {
      attrs: { "data-preserve-scroll-target": "self" },
    });

    hook.el.scrollTop = 84;

    hook.beforeUpdate();
    hook.el.scrollTop = 0;
    hook.updated();

    expect(hook.el.scrollTop).toBe(84);
  });
});
