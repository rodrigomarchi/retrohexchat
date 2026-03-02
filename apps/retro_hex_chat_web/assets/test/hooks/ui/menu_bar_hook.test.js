import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import MenuBarHook from "../../../js/hooks/ui/menu_bar_hook.js";

describe("MenuBarHook", () => {
  let hook;

  function createMenuBar() {
    return mountHook(MenuBarHook, {
      tag: "nav",
      attrs: { role: "menubar" },
      html: `
        <div class="relative inline-flex">
          <button data-menubar-trigger>File</button>
          <div data-menubar-dropdown class="u-hidden">
            <ul><li>Disconnect</li><li>Settings</li></ul>
          </div>
        </div>
        <div class="relative inline-flex">
          <button data-menubar-trigger>View</button>
          <div data-menubar-dropdown class="u-hidden">
            <ul><li>Channel List</li></ul>
          </div>
        </div>
        <div class="relative inline-flex">
          <button data-menubar-trigger data-disabled="true">Tools</button>
          <div data-menubar-dropdown class="u-hidden">
            <ul><li>Address Book</li></ul>
          </div>
        </div>
        <div class="relative inline-flex">
          <button data-menubar-trigger>Help</button>
          <div data-menubar-dropdown class="u-hidden">
            <ul><li>Help Topics</li></ul>
          </div>
        </div>
      `,
    });
  }

  beforeEach(() => {
    hook = createMenuBar();
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    cleanupDOM();
  });

  function triggers() {
    return hook.el.querySelectorAll("[data-menubar-trigger]");
  }

  function dropdowns() {
    return hook.el.querySelectorAll("[data-menubar-dropdown]");
  }

  function clickTrigger(index) {
    const trigger = triggers()[index];
    trigger.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
  }

  // ── open / close ────────────────────────────────────

  describe("open and close", () => {
    it("opens dropdown on trigger click", () => {
      clickTrigger(0); // File
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(false);
    });

    it("closes dropdown on second click (toggle)", () => {
      clickTrigger(0);
      clickTrigger(0);
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(true);
    });

    it("closes all on Escape", () => {
      clickTrigger(0);
      document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(true);
    });

    it("closes all on outside click", () => {
      clickTrigger(0);
      document.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(true);
    });

    it("closes on dropdown item click", () => {
      clickTrigger(0);
      const item = dropdowns()[0].querySelector("li");
      item.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(true);
    });
  });

  // ── hot tracking ────────────────────────────────────

  describe("hot tracking", () => {
    it("switches to another menu on hover when one is open", () => {
      clickTrigger(0); // Open File
      // Hover over View trigger
      const viewTrigger = triggers()[1];
      viewTrigger.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));

      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(true);
      expect(dropdowns()[1].classList.contains("u-hidden")).toBe(false);
    });

    it("does not open on hover when no menu is active", () => {
      const viewTrigger = triggers()[1];
      viewTrigger.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));

      expect(dropdowns()[1].classList.contains("u-hidden")).toBe(true);
    });
  });

  // ── disabled triggers ───────────────────────────────

  describe("disabled triggers", () => {
    it("does not open dropdown for disabled trigger", () => {
      clickTrigger(2); // Tools (disabled)
      expect(dropdowns()[2].classList.contains("u-hidden")).toBe(true);
    });

    it("does not switch to disabled trigger on hover", () => {
      clickTrigger(0); // Open File
      const toolsTrigger = triggers()[2];
      toolsTrigger.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));

      // File should still be open, Tools should not
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(false);
      expect(dropdowns()[2].classList.contains("u-hidden")).toBe(true);
    });
  });

  // ── active styling ──────────────────────────────────

  describe("active styling", () => {
    it("adds active classes to trigger when menu is open", () => {
      clickTrigger(0);
      const trigger = triggers()[0];
      expect(trigger.classList.contains("bg-primary")).toBe(true);
      expect(trigger.classList.contains("text-primary-foreground")).toBe(true);
    });

    it("removes active classes when menu is closed", () => {
      clickTrigger(0);
      clickTrigger(0);
      const trigger = triggers()[0];
      expect(trigger.classList.contains("bg-primary")).toBe(false);
      expect(trigger.classList.contains("text-primary-foreground")).toBe(false);
    });
  });
});
