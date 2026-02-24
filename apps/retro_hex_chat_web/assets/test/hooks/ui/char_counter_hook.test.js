import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import CharCounterHook from "../../../js/hooks/ui/char_counter_hook.js";

describe("CharCounterHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(CharCounterHook, {
      html: `
        <textarea id="chat-input"></textarea>
        <span data-testid="char-counter"></span>
      `,
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("shows 0/1000 on mount with empty input", () => {
    const counter = hook.el.querySelector("[data-testid='char-counter']");
    expect(counter.textContent).toBe("0/1000");
  });

  it("updates counter on input", () => {
    const input = hook.el.querySelector("#chat-input");
    const counter = hook.el.querySelector("[data-testid='char-counter']");
    input.value = "hello";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    expect(counter.textContent).toBe("5/1000");
  });

  it("adds warning class above 450 chars", () => {
    const input = hook.el.querySelector("#chat-input");
    const counter = hook.el.querySelector("[data-testid='char-counter']");
    input.value = "x".repeat(451);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    expect(counter.classList.contains("char-counter--warning")).toBe(true);
    expect(counter.classList.contains("char-counter--danger")).toBe(false);
  });

  it("adds danger class above 900 chars", () => {
    const input = hook.el.querySelector("#chat-input");
    const counter = hook.el.querySelector("[data-testid='char-counter']");
    input.value = "x".repeat(901);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    expect(counter.classList.contains("char-counter--danger")).toBe(true);
    expect(counter.classList.contains("char-counter--warning")).toBe(false);
  });

  it("removes classes when back to normal", () => {
    const input = hook.el.querySelector("#chat-input");
    const counter = hook.el.querySelector("[data-testid='char-counter']");
    input.value = "x".repeat(901);
    input.dispatchEvent(new Event("input", { bubbles: true }));
    input.value = "short";
    input.dispatchEvent(new Event("input", { bubbles: true }));
    expect(counter.classList.contains("char-counter--danger")).toBe(false);
    expect(counter.classList.contains("char-counter--warning")).toBe(false);
  });
});
