import {
  findShortcutAction,
  isModifierKey,
  shortcutActionFor,
} from "../../../js/lib/input/shortcuts.js";

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

  // ── shortcutActionFor ──────────────────────────────────

  describe("shortcutActionFor", () => {
    const bindings = {
      toggle_search: { key: "f", modifiers: ["ctrl", "shift"] },
      toggle_cheatsheet: { key: "/", modifiers: ["ctrl", "shift"] },
      window_prev: { key: "[", modifiers: ["ctrl", "shift"] },
      window_1: { key: "1", modifiers: ["ctrl", "shift"] },
      toggle_address_book: { key: "a", modifiers: ["ctrl", "shift"] },
    };

    it("reads the unshifted character Shift hides", () => {
      expect(shortcutActionFor(bindings, { key: "?", code: "Slash" })).toBe("toggle_cheatsheet");
      expect(shortcutActionFor(bindings, { key: "{", code: "BracketLeft" })).toBe("window_prev");
      expect(shortcutActionFor(bindings, { key: "!", code: "Digit1" })).toBe("window_1");
    });

    it("letters follow the layout, not the key's position", () => {
      // AZERTY: the key labelled A sits where QWERTY has Q.
      expect(shortcutActionFor(bindings, { key: "A", code: "KeyQ" })).toBe("toggle_address_book");
      expect(shortcutActionFor(bindings, { key: "F", code: "KeyF" })).toBe("toggle_search");
    });

    it("nothing bound is nothing triggered", () => {
      expect(shortcutActionFor(bindings, { key: "Z", code: "KeyZ" })).toBeNull();
      expect(shortcutActionFor(bindings, { key: "@", code: "Digit2" })).toBeNull();
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
