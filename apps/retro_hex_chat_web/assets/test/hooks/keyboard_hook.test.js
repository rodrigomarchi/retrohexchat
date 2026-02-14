import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import KeyboardHook from "../../js/hooks/keyboard_hook.js";

describe("KeyboardHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(KeyboardHook, { tag: "input" });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("pushes history_navigate up on ArrowUp", () => {
    hook.el.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowUp", bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("history_navigate", { direction: "up" });
  });

  it("pushes history_navigate down on ArrowDown", () => {
    hook.el.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowDown", bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("history_navigate", { direction: "down" });
  });

  it("pushes tab_complete on Tab", () => {
    hook.el.value = "/jo";
    hook.el.dispatchEvent(new KeyboardEvent("keydown", { key: "Tab", bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("tab_complete", { partial: "/jo" });
  });

  it("does not push for other keys", () => {
    hook.pushEvent.mockClear();
    hook.el.dispatchEvent(new KeyboardEvent("keydown", { key: "a", bubbles: true }));
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });
});
