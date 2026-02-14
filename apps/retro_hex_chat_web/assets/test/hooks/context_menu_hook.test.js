import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import ContextMenuHook from "../../js/hooks/context_menu_hook.js";

describe("ContextMenuHook", () => {
  let hook;

  function createMenu() {
    return mountHook(ContextMenuHook, {
      tag: "ul",
      attrs: { style: "position: fixed; left: 100px; top: 100px;" },
      html: `
        <li class="menu-item" phx-click="action1">Action 1</li>
        <li class="separator"></li>
        <li class="menu-item" phx-click="action2">Action 2</li>
        <li class="menu-item" phx-click="action3">Action 3</li>
      `,
    });
  }

  beforeEach(() => {
    hook = createMenu();
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  // ── keyboard navigation ────────────────────────────────

  describe("keyboard navigation", () => {
    it("ArrowDown focuses first item", () => {
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
      expect(hook.items[0].classList.contains("focused")).toBe(true);
    });

    it("ArrowUp focuses last item", () => {
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true }));
      expect(hook.items[hook.items.length - 1].classList.contains("focused")).toBe(true);
    });

    it("Enter clicks the focused item", () => {
      let clicked = false;
      hook.items[0].addEventListener("click", () => {
        clicked = true;
      });

      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
      expect(clicked).toBe(true);
    });
  });

  // ── wrap around ────────────────────────────────────────

  describe("wrap around", () => {
    it("wraps from last to first", () => {
      // Go to last item
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true }));
      expect(hook.focusedIndex).toBe(hook.items.length - 1);

      // Go down past last → wraps to first
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
      expect(hook.focusedIndex).toBe(0);
    });

    it("wraps from first to last", () => {
      // Go to first item
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
      expect(hook.focusedIndex).toBe(0);

      // Go up past first → wraps to last
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true }));
      expect(hook.focusedIndex).toBe(hook.items.length - 1);
    });
  });

  // ── Escape ─────────────────────────────────────────────

  describe("Escape", () => {
    it("pushes close events on Escape", () => {
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      expect(hook.pushEvent).toHaveBeenCalledWith("close_chat_context_menu", {});
      expect(hook.pushEvent).toHaveBeenCalledWith("close_treebar_context_menu", {});
    });
  });
});
