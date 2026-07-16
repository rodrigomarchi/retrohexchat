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
    hook?.destroyed?.();
    vi.useRealTimers();
    cleanupDOM();
  });

  function pointerEvent(type, attrs = {}) {
    const event = new Event(type, { bubbles: true, cancelable: true });
    for (const [key, value] of Object.entries(attrs)) {
      Object.defineProperty(event, key, { value, configurable: true });
    }
    return event;
  }

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

  it("opens the channel context menu from a touch long press", () => {
    vi.useFakeTimers();
    const li = hook.el.querySelector("[data-channel='#general']");

    li.dispatchEvent(
      pointerEvent("pointerdown", {
        pointerType: "touch",
        button: 0,
        clientX: 44,
        clientY: 88,
      }),
    );
    vi.advanceTimersByTime(550);

    expect(hook.pushEvent).toHaveBeenCalledWith("channel_right_click", {
      channel: "#general",
      x: 44,
      y: 88,
    });
  });

  it("opens the PM context menu from a touch long press", () => {
    vi.useFakeTimers();
    const li = hook.el.querySelector("[data-nick='Alice']");

    li.dispatchEvent(
      pointerEvent("pointerdown", {
        pointerType: "touch",
        button: 0,
        clientX: 20,
        clientY: 30,
      }),
    );
    vi.advanceTimersByTime(550);

    expect(hook.pushEvent).toHaveBeenCalledWith("pm_right_click", {
      nick: "Alice",
      x: 20,
      y: 30,
    });
  });
});
