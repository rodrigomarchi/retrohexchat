import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import MenuBarHook from "../../../js/hooks/ui/menu_bar_hook.js";

describe("MenuBarHook", () => {
  let hook;
  let originalClipboard;
  let originalExecCommand;

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
          <button data-menubar-trigger>Edit</button>
          <div data-menubar-dropdown class="u-hidden">
            <ul>
              <li data-menubar-copy-selection data-testid="context-menu-item-copy_selection" class="hover:bg-selection-bg hover:text-selection-fg">Copy</li>
            </ul>
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
    originalClipboard = navigator.clipboard;
    originalExecCommand = document.execCommand;
    hook = createMenuBar();
  });

  afterEach(() => {
    if (hook.destroyed) hook.destroyed();
    vi.restoreAllMocks();
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: originalClipboard,
    });
    document.execCommand = originalExecCommand;
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

  function copyItem() {
    return hook.el.querySelector("[data-menubar-copy-selection]");
  }

  function stubSelection(text, container) {
    const textNode = container.firstChild || container;
    vi.spyOn(window, "getSelection").mockReturnValue({
      rangeCount: text ? 1 : 0,
      toString: () => text,
      getRangeAt: () => ({ commonAncestorContainer: textNode }),
    });
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
      const viewTrigger = triggers()[2];
      viewTrigger.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));

      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(true);
      expect(dropdowns()[2].classList.contains("u-hidden")).toBe(false);
    });

    it("does not open on hover when no menu is active", () => {
      const viewTrigger = triggers()[2];
      viewTrigger.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));

      expect(dropdowns()[2].classList.contains("u-hidden")).toBe(true);
    });
  });

  // ── disabled triggers ───────────────────────────────

  describe("disabled triggers", () => {
    it("does not open dropdown for disabled trigger", () => {
      clickTrigger(3); // Tools (disabled)
      expect(dropdowns()[3].classList.contains("u-hidden")).toBe(true);
    });

    it("does not switch to disabled trigger on hover", () => {
      clickTrigger(0); // Open File
      const toolsTrigger = triggers()[3];
      toolsTrigger.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));

      // File should still be open, Tools should not
      expect(dropdowns()[0].classList.contains("u-hidden")).toBe(false);
      expect(dropdowns()[3].classList.contains("u-hidden")).toBe(true);
    });
  });

  // ── copy selection ──────────────────────────────────

  describe("copy selection", () => {
    it("disables Copy when no chat-log selection exists at menu-open time", () => {
      stubSelection("", document.body);

      clickTrigger(1); // Edit

      expect(copyItem().dataset.copyDisabled).toBe("true");
      expect(copyItem().getAttribute("aria-disabled")).toBe("true");
      expect(copyItem().classList.contains("menubar-copy-disabled")).toBe(true);
    });

    it("enables Copy when selected text is inside the chat log", () => {
      const chatLog = document.createElement("div");
      chatLog.id = "chat-messages";
      chatLog.textContent = "selected chat text";
      document.body.appendChild(chatLog);
      stubSelection("selected chat text", chatLog);

      clickTrigger(1); // Edit

      expect(copyItem().dataset.copyDisabled).toBe("false");
      expect(copyItem().getAttribute("aria-disabled")).toBe("false");
      expect(copyItem().classList.contains("menubar-copy-disabled")).toBe(false);
    });

    it("copies selected chat-log text through the Clipboard API without a server event", () => {
      const chatLog = document.createElement("div");
      chatLog.id = "chat-messages";
      chatLog.textContent = "copy me";
      document.body.appendChild(chatLog);
      stubSelection("copy me", chatLog);

      const writeText = vi.fn().mockResolvedValue(undefined);
      Object.defineProperty(navigator, "clipboard", {
        configurable: true,
        value: { writeText },
      });

      clickTrigger(1); // Edit
      copyItem().dispatchEvent(new MouseEvent("click", { bubbles: true }));

      expect(writeText).toHaveBeenCalledWith("copy me");
      expect(hook.pushEvent).not.toHaveBeenCalled();
      expect(dropdowns()[1].classList.contains("u-hidden")).toBe(true);
    });

    it("falls back to execCommand when the Clipboard API is unavailable", () => {
      const chatLog = document.createElement("div");
      chatLog.id = "chat-messages";
      chatLog.textContent = "fallback copy";
      document.body.appendChild(chatLog);
      stubSelection("fallback copy", chatLog);

      Object.defineProperty(navigator, "clipboard", {
        configurable: true,
        value: undefined,
      });
      document.execCommand = vi.fn();

      clickTrigger(1); // Edit
      copyItem().dispatchEvent(new MouseEvent("click", { bubbles: true }));

      expect(document.execCommand).toHaveBeenCalledWith("copy");
      expect(hook.pushEvent).not.toHaveBeenCalled();
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
