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

  // The nicklist goes away (a channel closed, the window shut) with the
  // pointer still resting on a nick: the hover card it was about to ask for
  // belongs to a view that no longer exists.
  it("asks for no hover card once it is gone", () => {
    vi.useFakeTimers();
    const nick = hook.el.querySelector("[data-nick='Alice']");
    nick.dispatchEvent(new MouseEvent("mouseenter", { bubbles: false }));

    hook.destroyed();
    vi.advanceTimersByTime(1000);

    expect(hook.pushEvent).not.toHaveBeenCalledWith("nick_hover", expect.anything());
  });

  // Every listener it put on the list comes off with it.
  it("takes every listener off when it goes", () => {
    hook.destroyed();
    const added = vi.spyOn(hook.el, "addEventListener");
    const removed = vi.spyOn(hook.el, "removeEventListener");
    hook.mounted();
    hook.destroyed();

    expect(added.mock.calls.length).toBeGreaterThan(0);
    for (const [type, fn, capture] of added.mock.calls) {
      expect(removed.mock.calls).toContainEqual([type, fn, capture]);
    }
    // Mounted again by afterEach's destroy, so leave it mounted.
    hook.mounted();
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
