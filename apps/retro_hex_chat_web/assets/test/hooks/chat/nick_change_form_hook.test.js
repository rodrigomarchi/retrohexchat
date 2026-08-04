import { mountHook, simulateEvent, cleanupDOM } from "../../helpers/hook_helper.js";
import NickChangeFormHook from "../../../js/hooks/chat/nick_change_form_hook.js";

describe("NickChangeFormHook", () => {
  let hook;
  let restoreLocalStorage;

  beforeEach(() => {
    restoreLocalStorage = forbidLocalStorage();
    hook = mountHook(NickChangeFormHook);
  });

  afterEach(() => {
    cleanupDOM();
    restoreLocalStorage();
  });

  it("registers a handler for submit_nick_change event", () => {
    expect(hook.handleEvent).toHaveBeenCalledWith("submit_nick_change", expect.any(Function));
  });

  it("calls requestSubmit on the nick-change-session-form when event fires", () => {
    const form = document.createElement("form");
    form.id = "nick-change-session-form";
    form.requestSubmit = vi.fn();
    document.body.appendChild(form);

    simulateEvent(hook, "submit_nick_change", {});

    expect(form.requestSubmit).toHaveBeenCalledTimes(1);
  });

  it("does not throw when form is not found", () => {
    expect(() => {
      simulateEvent(hook, "submit_nick_change", {});
    }).not.toThrow();
  });

  it("does not touch browser storage on submit_nick_change event", () => {
    const form = document.createElement("form");
    form.id = "nick-change-session-form";
    form.requestSubmit = vi.fn();
    document.body.appendChild(form);

    simulateEvent(hook, "submit_nick_change", {
      previous_nickname: "old",
      nickname: "new",
    });

    expect(form.requestSubmit).toHaveBeenCalledTimes(1);
  });
});

function forbidLocalStorage() {
  const original = globalThis.localStorage;

  const forbidden = {
    getItem: vi.fn(() => {
      throw new Error("localStorage must not be used by NickChangeFormHook");
    }),
    setItem: vi.fn(() => {
      throw new Error("localStorage must not be used by NickChangeFormHook");
    }),
    removeItem: vi.fn(() => {
      throw new Error("localStorage must not be used by NickChangeFormHook");
    }),
  };

  Object.defineProperty(globalThis, "localStorage", {
    value: forbidden,
    writable: true,
    configurable: true,
  });

  return () => {
    Object.defineProperty(globalThis, "localStorage", {
      value: original,
      writable: true,
      configurable: true,
    });
  };
}
