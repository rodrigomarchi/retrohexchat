import { mountHook, cleanupDOM } from "../helpers/hook_helper.js";
import TreebarHook from "../../js/hooks/treebar_hook.js";

describe("TreebarHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(TreebarHook, {
      tag: "ul",
      html: `
        <li data-channel="#general">#general</li>
        <li data-channel="#random">#random</li>
      `,
    });
  });

  afterEach(() => {
    cleanupDOM();
  });

  it("pushes channel_right_click on contextmenu", () => {
    const li = hook.el.querySelector("[data-channel='#general']");
    const event = new MouseEvent("contextmenu", {
      bubbles: true,
      cancelable: true,
      clientX: 50,
      clientY: 100,
    });
    li.dispatchEvent(event);
    expect(hook.pushEvent).toHaveBeenCalledWith("channel_right_click", {
      channel: "#general",
      x: 50,
      y: 100,
    });
  });

  it("does not push when right-clicking outside channel item", () => {
    hook.pushEvent.mockClear();
    const event = new MouseEvent("contextmenu", { bubbles: true, cancelable: true });
    hook.el.dispatchEvent(event);
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });
});
