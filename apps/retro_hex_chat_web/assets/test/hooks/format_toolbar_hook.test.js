import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import FormatToolbarHook from "../../js/hooks/format_toolbar_hook.js";

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
        <button class="format-btn" data-format-code="bold">B</button>
        <button class="format-btn" data-format-code="italic">I</button>
        <button class="format-btn" data-format-code="underline">U</button>
        <button class="format-btn" data-format-code="color">C</button>
        <div class="format-color-dropdown">
          <button class="color-swatch" data-color-code="4">Red</button>
        </div>
      `,
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("inserts bold code on Bold button mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='bold']");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(chatInput.value).toBe("\x02");
  });

  it("inserts italic code on Italic button mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='italic']");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(chatInput.value).toBe("\x1D");
  });

  it("toggles color dropdown on Color button mousedown", () => {
    const btn = hook.el.querySelector("[data-format-code='color']");
    const dropdown = hook.el.querySelector(".format-color-dropdown");
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(
      true,
    );
    btn.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(dropdown.classList.contains("format-color-dropdown--open")).toBe(
      false,
    );
  });

  it("inserts color code on swatch mousedown", () => {
    const swatch = hook.el.querySelector(".color-swatch[data-color-code='4']");
    swatch.dispatchEvent(new MouseEvent("mousedown", { bubbles: true }));
    expect(chatInput.value).toBe("\x034");
  });
});
