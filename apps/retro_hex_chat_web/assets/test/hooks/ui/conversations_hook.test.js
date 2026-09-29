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

  // A single click already opens the conversation, so a second one had nothing
  // left to do — and a double click is a gesture no finger performs. The
  // nicklist keeps its own, on its own rows, in its own hook.
  it("ignores a double-click: one click is the whole grammar", () => {
    hook.pushEvent.mockClear();
    const li = hook.el.querySelector("li[data-nick='Alice']");
    li.dispatchEvent(new MouseEvent("dblclick", { bubbles: true }));
    expect(hook.pushEvent).not.toHaveBeenCalled();
  });

  describe("the row menu button", () => {
    function menuButtonIn(selector) {
      const row = hook.el.querySelector(selector);
      const button = document.createElement("button");
      button.setAttribute("data-conversations-menu", "");
      button.getBoundingClientRect = () => ({ left: 12, bottom: 34 });
      row.appendChild(button);
      return button;
    }

    it("opens the channel menu at the button, not at the pointer", () => {
      hook.pushEvent.mockClear();
      menuButtonIn("[data-channel='#general']").dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true }),
      );

      expect(hook.pushEvent).toHaveBeenCalledWith("channel_right_click", {
        channel: "#general",
        x: 12,
        y: 34,
      });
    });

    it("opens the private conversation menu the same way", () => {
      hook.pushEvent.mockClear();
      menuButtonIn("li[data-nick='Alice']").dispatchEvent(
        new MouseEvent("click", { bubbles: true, cancelable: true }),
      );

      expect(hook.pushEvent).toHaveBeenCalledWith("pm_right_click", {
        nick: "Alice",
        x: 12,
        y: 34,
      });
    });

    it("keeps the click off the row, so the menu never navigates", () => {
      const event = new MouseEvent("click", { bubbles: true, cancelable: true });
      const stopped = vi.spyOn(event, "stopPropagation");

      menuButtonIn("[data-channel='#general']").dispatchEvent(event);

      expect(stopped).toHaveBeenCalled();
      expect(event.defaultPrevented).toBe(true);
    });
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
