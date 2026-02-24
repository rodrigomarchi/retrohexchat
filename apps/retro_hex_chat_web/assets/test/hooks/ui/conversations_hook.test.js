import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import ConversationsHook from "../../../js/hooks/ui/conversations_hook.js";

describe("ConversationsHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(ConversationsHook, {
      tag: "ul",
      html: `
        <li data-channel="#general">#general</li>
        <li data-channel="#random">#random</li>
        <li data-nick="Alice" phx-value-nick="Alice">Alice</li>
        <li data-nick="Bob" phx-value-nick="Bob">Bob</li>
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

  it("pushes nicklist_dblclick with nick on double-click", () => {
    const li = hook.el.querySelector("li[data-nick='Alice']");
    li.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).toHaveBeenCalledWith("nicklist_dblclick", { nick: "Alice" });
  });

  it("does not push dblclick when double-clicking outside a nick", () => {
    hook.pushEvent.mockClear();
    hook.el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });
});
