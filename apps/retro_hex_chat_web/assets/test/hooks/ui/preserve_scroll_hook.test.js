import { afterEach, describe, expect, it } from "vitest";

import PreserveScrollHook from "../../../js/hooks/ui/preserve_scroll_hook.js";
import { scrollPreserver } from "../../../js/lib/ui/scroll_preservation.js";
import { cleanupDOM, mountHook } from "../../helpers/hook_helper.js";

// The hook registers with this same singleton, so driving its patch callbacks
// exercises exactly the coordination the app wires into LiveSocket.
const preserveScrollPatchStart = scrollPreserver.patchStart;
const preserveScrollPatchEnd = scrollPreserver.patchEnd;
const preserveScrollBeforeElUpdated = scrollPreserver.beforeElUpdated;

function makeScrollable(el) {
  Object.defineProperties(el, {
    clientHeight: { configurable: true, value: 120 },
    clientWidth: { configurable: true, value: 80 },
    scrollHeight: { configurable: true, value: 600 },
    scrollWidth: { configurable: true, value: 320 },
  });
}

describe("PreserveScrollHook", () => {
  afterEach(() => {
    cleanupDOM();
  });

  it("restores the parent scroll position after a LiveView patch", () => {
    const parent = document.createElement("div");
    makeScrollable(parent);
    parent.scrollTop = 180;
    parent.scrollLeft = 12;
    document.body.appendChild(parent);

    mountHook(PreserveScrollHook, {
      parent,
      attrs: {
        id: "parent-scroll-preserver",
        "data-preserve-scroll-target": "parent",
      },
    });

    preserveScrollPatchStart();
    preserveScrollBeforeElUpdated(parent);
    parent.scrollTop = 0;
    parent.scrollLeft = 0;
    preserveScrollPatchEnd();

    expect(parent.scrollTop).toBe(180);
    expect(parent.scrollLeft).toBe(12);
  });

  it("can preserve its own scroll position", () => {
    const hook = mountHook(PreserveScrollHook, {
      attrs: {
        id: "self-scroll-preserver",
        "data-preserve-scroll-target": "self",
      },
    });
    makeScrollable(hook.el);

    hook.el.scrollTop = 84;

    preserveScrollPatchStart();
    preserveScrollBeforeElUpdated(hook.el);
    hook.el.scrollTop = 0;
    preserveScrollPatchEnd();

    expect(hook.el.scrollTop).toBe(84);
  });
});
