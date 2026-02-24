import {
  isClickNotDrag,
  createTooltip,
  removeTooltip,
  hasActiveTooltip,
  isContextMenuOpen,
  setContextMenuOpen,
  repositionWithinViewport,
  formatChannelTooltip,
  startNickHoverTimer,
  resetNickHoverTimer,
  cancelNickHoverTimer,
  getNickHoverTarget,
} from "../../../js/lib/chat/interactive.js";
import { cleanupDOM } from "../../helpers/hook_helper.js";

describe("lib/interactive", () => {
  afterEach(() => {
    removeTooltip();
    cancelNickHoverTimer();
    setContextMenuOpen(false);
    cleanupDOM();
  });

  // ── isClickNotDrag ──────────────────────────────────

  describe("isClickNotDrag", () => {
    it("returns true when no downPos provided", () => {
      expect(isClickNotDrag(null, { x: 100, y: 100 })).toBe(true);
    });

    it("returns true when mouse did not move", () => {
      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 100, y: 100 })).toBe(true);
    });

    it("returns true within threshold", () => {
      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 102, y: 101 })).toBe(true);
    });

    it("returns false when mouse moved beyond threshold", () => {
      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 104, y: 100 })).toBe(false);
    });

    it("returns false with diagonal movement beyond threshold", () => {
      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 104, y: 104 })).toBe(false);
    });

    it("supports custom threshold", () => {
      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 108, y: 100 }, 10)).toBe(true);
      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 111, y: 100 }, 10)).toBe(false);
    });

    it("returns false when text is selected", () => {
      // Simulate text selection
      const range = document.createRange();
      const el = document.createElement("span");
      el.textContent = "selected text";
      document.body.appendChild(el);
      range.selectNodeContents(el);
      window.getSelection().removeAllRanges();
      window.getSelection().addRange(range);

      expect(isClickNotDrag({ x: 100, y: 100 }, { x: 100, y: 100 })).toBe(false);

      window.getSelection().removeAllRanges();
    });
  });

  // ── createTooltip / removeTooltip ───────────────────

  describe("createTooltip", () => {
    it("creates a tooltip element in the DOM", () => {
      const el = createTooltip("Hello", 50, 50);
      expect(el).toBeTruthy();
      expect(el.textContent).toBe("Hello");
      expect(el.classList.contains("interactive-tooltip")).toBe(true);
      expect(document.body.contains(el)).toBe(true);
    });

    it("removes previous tooltip when creating a new one", () => {
      createTooltip("First", 50, 50);
      const second = createTooltip("Second", 100, 100);
      const tooltips = document.querySelectorAll(".interactive-tooltip");
      expect(tooltips.length).toBe(1);
      expect(tooltips[0]).toBe(second);
    });
  });

  describe("removeTooltip", () => {
    it("removes the active tooltip from the DOM", () => {
      createTooltip("Remove me", 50, 50);
      expect(hasActiveTooltip()).toBe(true);
      removeTooltip();
      expect(hasActiveTooltip()).toBe(false);
      expect(document.querySelectorAll(".interactive-tooltip").length).toBe(0);
    });

    it("is safe to call when no tooltip exists", () => {
      expect(() => removeTooltip()).not.toThrow();
    });
  });

  // ── isContextMenuOpen / setContextMenuOpen ──────────

  describe("context menu flag", () => {
    it("defaults to false", () => {
      expect(isContextMenuOpen()).toBe(false);
    });

    it("can be set to true", () => {
      setContextMenuOpen(true);
      expect(isContextMenuOpen()).toBe(true);
    });

    it("can be set back to false", () => {
      setContextMenuOpen(true);
      setContextMenuOpen(false);
      expect(isContextMenuOpen()).toBe(false);
    });
  });

  // ── repositionWithinViewport ────────────────────────

  describe("repositionWithinViewport", () => {
    it("returns same position when fully within viewport", () => {
      const pos = repositionWithinViewport(100, 100, 200, 150);
      expect(pos.x).toBe(100);
      expect(pos.y).toBe(100);
    });

    it("clamps to left edge", () => {
      const pos = repositionWithinViewport(-10, 100, 200, 150);
      expect(pos.x).toBe(4);
    });

    it("clamps to top edge", () => {
      const pos = repositionWithinViewport(100, -10, 200, 150);
      expect(pos.y).toBe(4);
    });
  });

  // ── formatChannelTooltip ────────────────────────────

  describe("formatChannelTooltip", () => {
    it("formats for unjoined channel with plural users", () => {
      const text = formatChannelTooltip("#dev", 5, false);
      expect(text).toBe("#dev \u2014 5 users \u2014 Click to join");
    });

    it("formats for joined channel", () => {
      const text = formatChannelTooltip("#dev", 3, true);
      expect(text).toBe("#dev \u2014 3 users \u2014 Click to switch");
    });

    it("uses singular for 1 user", () => {
      const text = formatChannelTooltip("#solo", 1, false);
      expect(text).toBe("#solo \u2014 1 user \u2014 Click to join");
    });
  });

  // ── Nick hover timer ────────────────────────────────

  describe("nick hover timer", () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it("fires callback after delay", () => {
      const cb = vi.fn();
      startNickHoverTimer("Mario", cb, 500);
      expect(cb).not.toHaveBeenCalled();
      vi.advanceTimersByTime(500);
      expect(cb).toHaveBeenCalledTimes(1);
    });

    it("tracks the target nick", () => {
      startNickHoverTimer("Luigi", vi.fn());
      expect(getNickHoverTarget()).toBe("Luigi");
    });

    it("cancels previous timer when starting a new one", () => {
      const cb1 = vi.fn();
      const cb2 = vi.fn();
      startNickHoverTimer("Mario", cb1, 500);
      startNickHoverTimer("Luigi", cb2, 500);
      vi.advanceTimersByTime(500);
      expect(cb1).not.toHaveBeenCalled();
      expect(cb2).toHaveBeenCalledTimes(1);
    });

    it("resets the timer countdown", () => {
      const cb = vi.fn();
      startNickHoverTimer("Mario", cb, 500);
      vi.advanceTimersByTime(300);
      resetNickHoverTimer(cb, 500);
      vi.advanceTimersByTime(300);
      expect(cb).not.toHaveBeenCalled();
      vi.advanceTimersByTime(200);
      expect(cb).toHaveBeenCalledTimes(1);
    });

    it("can be cancelled", () => {
      const cb = vi.fn();
      startNickHoverTimer("Mario", cb, 500);
      cancelNickHoverTimer();
      vi.advanceTimersByTime(600);
      expect(cb).not.toHaveBeenCalled();
      expect(getNickHoverTarget()).toBeNull();
    });
  });
});
