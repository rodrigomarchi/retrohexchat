import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { createScrollPreserver } from "../../../js/lib/ui/scroll_preservation.js";

// The controller schedules restores through requestAnimationFrame; run them
// synchronously so a test can assert the captured position was written back.
beforeEach(() => {
  vi.stubGlobal("requestAnimationFrame", (fn) => {
    fn();
    return 1;
  });
  vi.stubGlobal("cancelAnimationFrame", () => {});
});

afterEach(() => {
  vi.unstubAllGlobals();
  document.body.innerHTML = "";
});

function scrollable(id) {
  const parent = document.createElement("div");
  Object.defineProperties(parent, {
    clientHeight: { configurable: true, value: 120 },
    clientWidth: { configurable: true, value: 80 },
    scrollHeight: { configurable: true, value: 600 },
    scrollWidth: { configurable: true, value: 320 },
  });
  const child = document.createElement("div");
  child.id = id;
  child.dataset.preserveScrollTarget = "parent";
  parent.appendChild(child);
  document.body.appendChild(parent);
  return { parent, child };
}

describe("createScrollPreserver", () => {
  it("restores the scroll position captured at the patch boundary", () => {
    const preserver = createScrollPreserver();
    const { parent, child } = scrollable("a");
    preserver.register(child);

    parent.scrollTop = 84;
    preserver.patchStart();
    preserver.beforeElUpdated(child);
    parent.scrollTop = 0; // a browser scroll during the morph
    preserver.patchEnd();

    expect(parent.scrollTop).toBe(84);
  });

  it("clamps a restore to the container's scrollable range", () => {
    const preserver = createScrollPreserver();
    const { parent, child } = scrollable("b");
    preserver.register(child);

    parent.scrollTop = 5000; // beyond scrollHeight - clientHeight (480)
    preserver.patchStart();
    preserver.beforeElUpdated(child);
    preserver.patchEnd();

    expect(parent.scrollTop).toBe(480);
  });

  it("keeps two preservers independent", () => {
    const a = createScrollPreserver();
    const b = createScrollPreserver();
    const first = scrollable("c");
    const second = scrollable("d");
    a.register(first.child);
    b.register(second.child);

    first.parent.scrollTop = 100;
    a.patchStart();
    a.beforeElUpdated(first.child);
    first.parent.scrollTop = 0;
    a.patchEnd();

    // b never saw a patch; its element is untouched.
    expect(first.parent.scrollTop).toBe(100);
    expect(second.parent.scrollTop).toBe(0);
  });

  it("register returns a controller that detaches on destroy", () => {
    const preserver = createScrollPreserver();
    const { parent, child } = scrollable("e");
    const removeSpy = vi.spyOn(parent, "removeEventListener");

    const instance = preserver.register(child);
    instance.destroy();

    // The scroll listener bound to the container is removed.
    expect(removeSpy).toHaveBeenCalledWith("scroll", expect.any(Function));
    // After destroy, a patch touching the element no longer reaches it.
    expect(() => preserver.beforeElUpdated(child)).not.toThrow();
  });

  it("nested patch starts restore only once, at the outermost end", () => {
    const preserver = createScrollPreserver();
    const { parent, child } = scrollable("f");
    preserver.register(child);

    parent.scrollTop = 60;
    preserver.patchStart();
    preserver.patchStart();
    preserver.beforeElUpdated(child);
    parent.scrollTop = 0;
    preserver.patchEnd(); // inner: no restore yet
    expect(parent.scrollTop).toBe(0);
    preserver.patchEnd(); // outer: restore
    expect(parent.scrollTop).toBe(60);
  });
});
