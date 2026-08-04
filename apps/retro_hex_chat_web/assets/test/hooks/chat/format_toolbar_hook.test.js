import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import FormatToolbarHook from "../../../js/hooks/chat/format_toolbar_hook.js";

describe("FormatToolbarHook", () => {
  let hook;
  let chatInput;

  beforeEach(() => {
    chatInput = document.createElement("textarea");
    chatInput.id = "chat-input";
    chatInput.value = "";
    chatInput.selectionStart = 0;
    chatInput.selectionEnd = 0;
    document.body.appendChild(chatInput);

    hook = mountHook(FormatToolbarHook, {
      html: `
        <button data-format-toolbar-toggle aria-expanded="false" aria-controls="formatting-toolbar-panel">Format</button>
        <div id="formatting-toolbar-panel" class="formatting-toolbar__panel u-hidden" data-format-toolbar-panel aria-hidden="true">
        <button class="format-btn" data-format-code="bold">B</button>
        <button class="format-btn" data-format-code="italic">I</button>
        <button class="format-btn" data-format-code="underline">U</button>
          <button class="format-btn" data-format-code="color" aria-expanded="false">C</button>
          <button data-format-toolbar-close data-emoji-toggle="true">Emoji</button>
          <div class="format-color-dropdown" data-format-color-dropdown>
          <button data-format-color-swatch data-color-code="4">Red</button>
        </div>
        </div>
      `,
    });
  });

  afterEach(() => {
    hook.destroyed();
    cleanupDOM();
  });

  it("inserts bold code on Bold button mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='bold']");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(chatInput.value).toBe("\x02");
    expect(document.activeElement).toBe(chatInput);
  });

  it("inserts italic code on Italic button mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='italic']");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(chatInput.value).toBe("\x1D");
  });

  it("opens and closes the compact panel from the single toolbar toggle", () => {
    const toggle = hook.el.querySelector("[data-format-toolbar-toggle]");
    const panel = hook.el.querySelector("[data-format-toolbar-panel]");

    expect(panel.classList.contains("u-hidden")).toBe(true);
    expect(panel.getAttribute("aria-hidden")).toBe("true");
    expect(toggle.getAttribute("aria-expanded")).toBe("false");

    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(false);
    expect(panel.getAttribute("aria-hidden")).toBe("false");
    expect(toggle.getAttribute("aria-expanded")).toBe("true");

    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(true);
    expect(panel.getAttribute("aria-hidden")).toBe("true");
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
  });

  it("supports keyboard activation of the compact panel toggle", () => {
    const toggle = hook.el.querySelector("[data-format-toolbar-toggle]");
    const panel = hook.el.querySelector("[data-format-toolbar-panel]");

    toggle.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(false);
    expect(toggle.getAttribute("aria-expanded")).toBe("true");
  });

  it("toggles color dropdown on Color button mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='color']");
    const dropdown = hook.el.querySelector(".format-color-dropdown");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(true);
    expect(btn.getAttribute("aria-expanded")).toBe("true");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(false);
    expect(btn.getAttribute("aria-expanded")).toBe("false");
  });

  it("inserts color code on swatch mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='color']");
    const dropdown = hook.el.querySelector(".format-color-dropdown");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    const swatch = hook.el.querySelector("[data-format-color-swatch][data-color-code='4']");
    swatch.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(chatInput.value).toBe("\x034");
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(false);
  });

  it("closes the compact panel after clicking an external picker trigger", () => {
    const toggle = hook.el.querySelector("[data-format-toolbar-toggle]");
    const emoji = hook.el.querySelector("[data-format-toolbar-close]");
    const panel = hook.el.querySelector("[data-format-toolbar-panel]");
    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    emoji.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(false);

    emoji.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(true);
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
  });

  it("closes the compact panel on outside mousedown", () => {
    const toggle = hook.el.querySelector("[data-format-toolbar-toggle]");
    const panel = hook.el.querySelector("[data-format-toolbar-panel]");
    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    document.body.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(true);
    expect(toggle.getAttribute("aria-expanded")).toBe("false");
  });

  it("closes the compact panel on Escape and restores input focus", () => {
    const toggle = hook.el.querySelector("[data-format-toolbar-toggle]");
    const panel = hook.el.querySelector("[data-format-toolbar-panel]");
    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    expect(panel.classList.contains("u-hidden")).toBe(true);
    expect(document.activeElement).toBe(chatInput);
  });

  it("preserves open state across LiveView updates", () => {
    const toggle = hook.el.querySelector("[data-format-toolbar-toggle]");
    const panel = hook.el.querySelector("[data-format-toolbar-panel]");
    toggle.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    panel.classList.add("u-hidden");
    panel.setAttribute("aria-hidden", "true");
    hook.updated();

    expect(panel.classList.contains("u-hidden")).toBe(false);
    expect(panel.getAttribute("aria-hidden")).toBe("false");
  });

  it("prevents LiveView toolbar actions from stealing input focus on mousedown", () => {
    const btn = document.createElement("button");
    btn.dataset.formatToolbarLive = "";
    hook.el.appendChild(btn);
    chatInput.focus();

    const event = new MouseEvent("mousedown", { bubbles: true, cancelable: true });
    btn.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
    expect(document.activeElement).toBe(chatInput);
  });

  it("wraps the selected text with markdown bold syntax", () => {
    const btn = document.createElement("button");
    btn.className = "format-btn";
    btn.dataset.formatCode = "md-bold";
    hook.el.appendChild(btn);

    chatInput.value = "hello";
    chatInput.selectionStart = 0;
    chatInput.selectionEnd = 5;

    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    expect(chatInput.value).toBe("**hello**");
    expect(document.activeElement).toBe(chatInput);
  });

  it("inserts a fenced markdown code block", () => {
    const btn = document.createElement("button");
    btn.className = "format-btn";
    btn.dataset.formatCode = "md-code-block";
    hook.el.appendChild(btn);

    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    expect(chatInput.value).toBe("```\ncode\n```");
  });

  it("wraps the selected text with markdown strikethrough syntax", () => {
    const btn = document.createElement("button");
    btn.className = "format-btn";
    btn.dataset.formatCode = "md-strike";
    hook.el.appendChild(btn);

    chatInput.value = "done";
    chatInput.selectionStart = 0;
    chatInput.selectionEnd = 4;

    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    expect(chatInput.value).toBe("~~done~~");
  });

  it("prefixes selected lines as a markdown heading", () => {
    const btn = document.createElement("button");
    btn.className = "format-btn";
    btn.dataset.formatCode = "md-heading";
    hook.el.appendChild(btn);

    chatInput.value = "Title";
    chatInput.selectionStart = 0;
    chatInput.selectionEnd = 5;

    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    expect(chatInput.value).toBe("# Title");
  });

  it("numbers selected lines as a markdown ordered list", () => {
    const btn = document.createElement("button");
    btn.className = "format-btn";
    btn.dataset.formatCode = "md-ordered-list";
    hook.el.appendChild(btn);

    chatInput.value = "one\ntwo";
    chatInput.selectionStart = 0;
    chatInput.selectionEnd = 7;

    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));

    expect(chatInput.value).toBe("1. one\n2. two");
  });
});
