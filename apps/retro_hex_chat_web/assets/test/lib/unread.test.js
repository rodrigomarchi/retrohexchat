import { describe, it, expect, beforeEach } from "vitest";
import {
  formatCount,
  createBadgeElement,
  updateBadge,
  clearBadge,
  MAX_DISPLAY_COUNT,
  BADGE_CLASS,
  BADGE_HIGHLIGHT_CLASS,
} from "../../js/lib/unread.js";

describe("unread", () => {
  describe("formatCount", () => {
    it("returns empty string for 0", () => {
      expect(formatCount(0)).toBe("");
    });

    it("returns number as string for 1..99", () => {
      expect(formatCount(1)).toBe("1");
      expect(formatCount(42)).toBe("42");
      expect(formatCount(99)).toBe("99");
    });

    it('returns "99+" for counts above 99', () => {
      expect(formatCount(100)).toBe("99+");
      expect(formatCount(999)).toBe("99+");
    });
  });

  describe("createBadgeElement", () => {
    it("creates a span with badge class and count text", () => {
      const el = createBadgeElement(5, false);
      expect(el.tagName).toBe("SPAN");
      expect(el.classList.contains(BADGE_CLASS)).toBe(true);
      expect(el.textContent).toBe("5");
    });

    it("adds highlight class when isHighlight is true", () => {
      const el = createBadgeElement(3, true);
      expect(el.classList.contains(BADGE_CLASS)).toBe(true);
      expect(el.classList.contains(BADGE_HIGHLIGHT_CLASS)).toBe(true);
    });

    it("caps display at 99+", () => {
      const el = createBadgeElement(150, false);
      expect(el.textContent).toBe("99+");
    });
  });

  describe("updateBadge", () => {
    let listItem;

    beforeEach(() => {
      listItem = document.createElement("li");
      listItem.textContent = "#general";
    });

    it("adds a badge when count > 0", () => {
      updateBadge(listItem, 3, false);
      const badge = listItem.querySelector(`.${BADGE_CLASS}`);
      expect(badge).not.toBeNull();
      expect(badge.textContent).toBe("3");
    });

    it("removes badge when count is 0", () => {
      updateBadge(listItem, 5, false);
      updateBadge(listItem, 0, false);
      const badge = listItem.querySelector(`.${BADGE_CLASS}`);
      expect(badge).toBeNull();
    });

    it("updates existing badge text", () => {
      updateBadge(listItem, 3, false);
      updateBadge(listItem, 7, false);
      const badges = listItem.querySelectorAll(`.${BADGE_CLASS}`);
      expect(badges.length).toBe(1);
      expect(badges[0].textContent).toBe("7");
    });

    it("adds highlight class when isHighlight is true", () => {
      updateBadge(listItem, 3, true);
      const badge = listItem.querySelector(`.${BADGE_CLASS}`);
      expect(badge.classList.contains(BADGE_HIGHLIGHT_CLASS)).toBe(true);
    });

    it("removes highlight class when isHighlight changes to false", () => {
      updateBadge(listItem, 3, true);
      updateBadge(listItem, 3, false);
      const badge = listItem.querySelector(`.${BADGE_CLASS}`);
      expect(badge.classList.contains(BADGE_HIGHLIGHT_CLASS)).toBe(false);
    });
  });

  describe("clearBadge", () => {
    it("removes badge from list item", () => {
      const li = document.createElement("li");
      updateBadge(li, 5, false);
      clearBadge(li);
      expect(li.querySelector(`.${BADGE_CLASS}`)).toBeNull();
    });

    it("is a no-op when no badge exists", () => {
      const li = document.createElement("li");
      clearBadge(li);
      expect(li.querySelector(`.${BADGE_CLASS}`)).toBeNull();
    });
  });

  describe("constants", () => {
    it("exports MAX_DISPLAY_COUNT as 99", () => {
      expect(MAX_DISPLAY_COUNT).toBe(99);
    });
  });
});
