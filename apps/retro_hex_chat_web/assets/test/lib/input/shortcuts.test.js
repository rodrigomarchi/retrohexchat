import { findShortcutAction, isModifierKey } from "../../../js/lib/input/shortcuts.js";

describe("lib/shortcuts", () => {
  // ── findShortcutAction ─────────────────────────────────

  describe("findShortcutAction", () => {
    const bindings = {
      toggle_search: { key: "f", modifiers: ["ctrl", "shift"] },
      next_channel: { key: "ArrowRight", modifiers: ["ctrl", "shift"] },
      null_binding: null,
    };

    it("finds matching action", () => {
      expect(findShortcutAction(bindings, "f")).toBe("toggle_search");
    });

    it("matches non-letter keys", () => {
      expect(findShortcutAction(bindings, "ArrowRight")).toBe("next_channel");
    });

    it("returns null for no match", () => {
      expect(findShortcutAction(bindings, "z")).toBeNull();
    });

    it("skips null bindings", () => {
      expect(findShortcutAction(bindings, "x")).toBeNull();
    });

    it("requires exactly ctrl+shift modifiers", () => {
      const badBindings = {
        action: { key: "f", modifiers: ["ctrl"] },
      };
      expect(findShortcutAction(badBindings, "f")).toBeNull();
    });
  });

  // ── isModifierKey ──────────────────────────────────────

  describe("isModifierKey", () => {
    it("returns true for modifier keys", () => {
      expect(isModifierKey("Control")).toBe(true);
      expect(isModifierKey("Alt")).toBe(true);
      expect(isModifierKey("Shift")).toBe(true);
      expect(isModifierKey("Meta")).toBe(true);
    });

    it("returns false for regular keys", () => {
      expect(isModifierKey("a")).toBe(false);
      expect(isModifierKey("Enter")).toBe(false);
      expect(isModifierKey("ArrowUp")).toBe(false);
    });
  });
});
