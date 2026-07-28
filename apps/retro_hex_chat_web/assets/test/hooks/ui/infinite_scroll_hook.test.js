import { afterEach, describe, expect, it } from "vitest";

import InfiniteScrollHook from "../../../js/hooks/ui/infinite_scroll_hook.js";
import { cleanupDOM, getPushEvents, mountHook } from "../../helpers/hook_helper.js";

// jsdom reports 0 for every layout box, so the scroll geometry has to be faked.
function makeScrollable(el, { scrollHeight = 2000, clientHeight = 400 } = {}) {
  Object.defineProperties(el, {
    clientHeight: { configurable: true, value: clientHeight },
    scrollHeight: { configurable: true, value: scrollHeight },
  });
}

function mount(attrs = {}, geometry = {}) {
  const hook = mountHook(InfiniteScrollHook, {
    attrs: {
      id: "paged-list",
      "data-has-more": "true",
      ...attrs,
    },
  });
  makeScrollable(hook.el, geometry);
  return hook;
}

// A real user gesture is a precondition for paginating; programmatic scrolls
// must never trigger a fetch.
function userGesture(el) {
  el.dispatchEvent(new WheelEvent("wheel", { bubbles: true, deltaY: -100 }));
}

function scrollTo(hook, top) {
  hook.el.scrollTop = top;
  hook.el.dispatchEvent(new Event("scroll", { bubbles: true }));
}

function loadMoreEvents(hook) {
  return getPushEvents(hook, "load_more");
}

describe("InfiniteScrollHook", () => {
  afterEach(() => {
    cleanupDOM();
  });

  describe("edge detection", () => {
    it("fires before reaching the very top, within the threshold", () => {
      const hook = mount({ "data-edge": "top", "data-threshold": "400" });

      userGesture(hook.el);
      scrollTo(hook, 300);

      expect(loadMoreEvents(hook)).toHaveLength(1);
    });

    it("does not fire while still outside the threshold", () => {
      const hook = mount({ "data-edge": "top", "data-threshold": "400" });

      userGesture(hook.el);
      scrollTo(hook, 900);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });

    it("fires near the bottom edge when configured that way", () => {
      const hook = mount({ "data-edge": "bottom", "data-threshold": "400" });

      userGesture(hook.el);
      // scrollHeight 2000, clientHeight 400 -> max scrollTop is 1600.
      scrollTo(hook, 1300);

      expect(loadMoreEvents(hook)).toHaveLength(1);
    });

    it("does not fire near the top when watching the bottom edge", () => {
      const hook = mount({ "data-edge": "bottom", "data-threshold": "400" });

      userGesture(hook.el);
      scrollTo(hook, 10);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });

    it("defaults to the bottom edge with a threshold well past the old 10px", () => {
      const hook = mount();

      userGesture(hook.el);
      scrollTo(hook, 1300);

      expect(loadMoreEvents(hook)).toHaveLength(1);
    });
  });

  describe("user scroll intent", () => {
    it("does not fire for a programmatic scroll with no preceding gesture", () => {
      const hook = mount({ "data-edge": "top" });

      scrollTo(hook, 0);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });

    it("accepts a keyboard gesture as intent", () => {
      const hook = mount({ "data-edge": "top" });

      hook.el.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "PageUp" }));
      scrollTo(hook, 100);

      expect(loadMoreEvents(hook)).toHaveLength(1);
    });

    it("ignores a keystroke that does not scroll", () => {
      const hook = mount({ "data-edge": "top" });

      hook.el.dispatchEvent(new KeyboardEvent("keydown", { bubbles: true, key: "a" }));
      scrollTo(hook, 100);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });
  });

  describe("server-owned guards", () => {
    it("does not fire when the server says there is nothing more", () => {
      const hook = mount({ "data-edge": "top", "data-has-more": "false" });

      userGesture(hook.el);
      scrollTo(hook, 0);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });

    it("does not fire while a page is already loading", () => {
      const hook = mount({ "data-edge": "top", "data-loading": "true" });

      userGesture(hook.el);
      scrollTo(hook, 0);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });

    it("does not fire again until the server has answered the first request", () => {
      const hook = mount({ "data-edge": "top" });

      userGesture(hook.el);
      scrollTo(hook, 100);
      scrollTo(hook, 50);
      scrollTo(hook, 0);

      expect(loadMoreEvents(hook)).toHaveLength(1);
    });

    it("fires again once a patch has landed", () => {
      const hook = mount({ "data-edge": "top" });

      userGesture(hook.el);
      scrollTo(hook, 100);
      expect(loadMoreEvents(hook)).toHaveLength(1);

      hook.updated();
      userGesture(hook.el);
      scrollTo(hook, 50);

      expect(loadMoreEvents(hook)).toHaveLength(2);
    });
  });

  describe("_overran", () => {
    it("reports an overrun when the reader jumps to the edge in one move", () => {
      const hook = mount({ "data-edge": "top" });

      userGesture(hook.el);
      // The hook learns its position from scroll events, so the starting point
      // has to be scrolled to, not assigned. From deep in the list straight to
      // the top: more than a viewport in one event, landing on the edge.
      scrollTo(hook, 1600);
      scrollTo(hook, 0);

      expect(loadMoreEvents(hook)[0]).toEqual({ _overran: true });
    });

    it("does not report an overrun for ordinary gradual scrolling", () => {
      const hook = mount({ "data-edge": "top", "data-threshold": "400" });

      userGesture(hook.el);
      scrollTo(hook, 500);
      scrollTo(hook, 300);

      expect(loadMoreEvents(hook)[0]).toEqual({});
    });
  });

  describe("targeting", () => {
    it("pushes to the island when data-target is present", () => {
      const hook = mount({ "data-edge": "top", "data-target": "42" });

      userGesture(hook.el);
      scrollTo(hook, 100);

      expect(hook.pushEventTo).toHaveBeenCalledWith("42", "load_more", {});
    });

    it("pushes to the root LiveView when there is no target", () => {
      const hook = mount({ "data-edge": "top" });

      userGesture(hook.el);
      scrollTo(hook, 100);

      expect(hook.pushEvent).toHaveBeenCalledWith("load_more", {});
    });

    // An island frequently owns more than one paginated list (Trusted Terminals
    // has two, Channel Central four). They share a phx-target, so the event name
    // is what tells them apart, and like every other setting it is the server's
    // to choose.
    it("pushes the event name the server asked for", () => {
      const hook = mount({
        "data-edge": "top",
        "data-target": "7",
        "data-event": "load_more_events",
      });

      userGesture(hook.el);
      scrollTo(hook, 100);

      expect(hook.pushEventTo).toHaveBeenCalledWith("7", "load_more_events", {});
    });

    it("falls back to load_more when the server names no event", () => {
      const hook = mount({ "data-edge": "top", "data-target": "7" });

      userGesture(hook.el);
      scrollTo(hook, 100);

      expect(hook.pushEventTo).toHaveBeenCalledWith("7", "load_more", {});
    });
  });

  describe("prepend position preservation", () => {
    it("keeps the reading position when older rows land above", () => {
      const hook = mount({ "data-edge": "top" });
      hook.el.scrollTop = 120;

      // Before the patch the list is 2000 tall; after it is 3000, because a
      // page of older rows was prepended. Without compensation the reader would
      // be thrown 1000px away from what they were reading.
      hook.beforeUpdate();
      makeScrollable(hook.el, { scrollHeight: 3000 });
      hook.updated();

      expect(hook.el.scrollTop).toBe(1120);
    });

    it("leaves the position alone when watching the bottom edge", () => {
      const hook = mount({ "data-edge": "bottom" });
      hook.el.scrollTop = 120;

      hook.beforeUpdate();
      makeScrollable(hook.el, { scrollHeight: 3000 });
      hook.updated();

      expect(hook.el.scrollTop).toBe(120);
    });
  });

  describe("teardown", () => {
    it("stops listening once destroyed", () => {
      const hook = mount({ "data-edge": "top" });

      hook.destroyed();
      userGesture(hook.el);
      scrollTo(hook, 0);

      expect(loadMoreEvents(hook)).toHaveLength(0);
    });
  });
});
