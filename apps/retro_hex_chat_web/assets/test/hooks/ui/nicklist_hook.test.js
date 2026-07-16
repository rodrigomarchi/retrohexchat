import { mountHook, cleanupDOM } from "../../helpers/hook_helper.js";
import NicklistHook from "../../../js/hooks/ui/nicklist_hook.js";

describe("NicklistHook", () => {
  let hook;

  beforeEach(() => {
    hook = mountHook(NicklistHook, {
      html: `
        <div data-nick="Alice">Alice</div>
        <div data-nick="Bob">Bob</div>
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

  it("opens the nick context menu on right-click", () => {
    const nick = hook.el.querySelector("[data-nick='Alice']");
    nick.dispatchEvent(
      new MouseEvent("contextmenu", {
        bubbles: true,
        cancelable: true,
        clientX: 12,
        clientY: 24,
      }),
    );

    expect(hook.pushEvent).toHaveBeenCalledWith("nick_right_click", {
      nick: "Alice",
      x: 12,
      y: 24,
    });
  });

  it("opens the nick context menu from a touch long press", () => {
    vi.useFakeTimers();
    const nick = hook.el.querySelector("[data-nick='Bob']");

    nick.dispatchEvent(
      pointerEvent("pointerdown", {
        pointerType: "touch",
        button: 0,
        clientX: 40,
        clientY: 64,
      }),
    );
    vi.advanceTimersByTime(550);

    expect(hook.pushEvent).toHaveBeenCalledWith("nick_right_click", {
      nick: "Bob",
      x: 40,
      y: 64,
    });
  });

  it("cancels long press when touch moves beyond tolerance", () => {
    vi.useFakeTimers();
    const nick = hook.el.querySelector("[data-nick='Bob']");

    nick.dispatchEvent(
      pointerEvent("pointerdown", {
        pointerType: "touch",
        button: 0,
        clientX: 40,
        clientY: 64,
      }),
    );
    nick.dispatchEvent(
      pointerEvent("pointermove", {
        pointerType: "touch",
        clientX: 70,
        clientY: 64,
      }),
    );
    vi.advanceTimersByTime(550);

    expect(hook.pushEvent).not.toHaveBeenCalledWith("nick_right_click", expect.anything());
  });
});
