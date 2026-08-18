import { describe, expect, it, vi } from "vitest";

import { createViewportScroller } from "../../../js/lib/chat/viewport_scroll.js";

// A scroller whose geometry we control, plus fake observers that hand back
// their callbacks so a test can fire them.
function harness({ scrollHeight = 1000, clientHeight = 200 } = {}) {
  let ioCb;
  let moCb;
  const scroller = { scrollTop: 0, scrollHeight, clientHeight };
  const anchor = {};
  const stream = { replaceChildren: vi.fn() };

  const IntersectionObserver = class {
    constructor(cb) {
      ioCb = cb;
    }
    observe() {}
    disconnect() {}
  };
  const MutationObserver = class {
    constructor(cb) {
      moCb = cb;
    }
    observe() {}
    disconnect() {}
  };
  const ResizeObserver = class {
    observe() {}
    disconnect() {}
  };

  const scroller_ = createViewportScroller(scroller, {
    stream,
    anchor,
    IntersectionObserver,
    MutationObserver,
    ResizeObserver,
  });
  scroller_.mount();

  return {
    scroller,
    stream,
    controller: scroller_,
    setPinned: (v) => ioCb([{ isIntersecting: v }]),
    fireContentChange: () => moCb(),
  };
}

describe("createViewportScroller", () => {
  it("scrolls to the bottom on mount", () => {
    const { scroller } = harness();
    expect(scroller.scrollTop).toBe(scroller.scrollHeight);
  });

  it("stays at the bottom on new content while pinned", () => {
    const h = harness();
    h.setPinned(true);
    h.scroller.scrollHeight = 1500; // a new line arrived
    h.fireContentChange();
    expect(h.scroller.scrollTop).toBe(1500);
  });

  it("does not move on new content while unpinned", () => {
    const h = harness();
    h.setPinned(false);
    h.scroller.scrollTop = 300;
    h.scroller.scrollHeight = 1500;
    h.fireContentChange();
    expect(h.scroller.scrollTop).toBe(300);
  });

  it("preserves the distance from the bottom across a prepend", () => {
    const h = harness();
    h.setPinned(false);
    h.scroller.scrollTop = 700; // 300px from the bottom of 1000
    h.controller.prepareForPrepend();
    expect(h.controller.pendingPrepend).toBe(300);

    h.scroller.scrollHeight = 1600; // a page of history landed above
    h.fireContentChange();
    // still 300px from the bottom
    expect(h.scroller.scrollHeight - h.scroller.scrollTop).toBe(300);
    expect(h.controller.pendingPrepend).toBeNull();
  });

  it("reset pins and jumps to the bottom", () => {
    const h = harness();
    h.setPinned(false);
    h.scroller.scrollTop = 100;
    h.controller.reset();
    expect(h.scroller.scrollTop).toBe(h.scroller.scrollHeight);
    expect(h.controller.pinned).toBe(true);
  });

  it("clearMessages empties the stream and pins", () => {
    const h = harness();
    h.setPinned(false);
    h.controller.clearMessages();
    expect(h.stream.replaceChildren).toHaveBeenCalled();
    expect(h.controller.pinned).toBe(true);
  });

  it("disconnects observers on destroy", () => {
    const disconnect = vi.fn();
    const scroller = { scrollTop: 0, scrollHeight: 100, clientHeight: 50 };
    const Obs = class {
      observe() {}
      disconnect = disconnect;
    };
    const c = createViewportScroller(scroller, {
      anchor: {},
      IntersectionObserver: Obs,
      MutationObserver: Obs,
      ResizeObserver: Obs,
    });
    c.mount();
    c.destroy();
    expect(disconnect).toHaveBeenCalledTimes(3);
  });
});
