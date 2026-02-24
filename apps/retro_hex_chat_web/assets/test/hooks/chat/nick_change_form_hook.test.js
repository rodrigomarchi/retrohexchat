import {
  mountHook,
  simulateEvent,
  cleanupDOM,
  mockLocalStorage,
} from "../../helpers/hook_helper.js";
import NickChangeFormHook from "../../../js/hooks/chat/nick_change_form_hook.js";

describe("NickChangeFormHook", () => {
  let hook;
  let storage;

  beforeEach(() => {
    storage = mockLocalStorage();
    hook = mountHook(NickChangeFormHook);
  });

  afterEach(() => {
    cleanupDOM();
    storage.restore();
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

  it("removes rhc_reconnect_state on submit_nick_change event", () => {
    storage.store["rhc_reconnect_state"] = JSON.stringify({ channels: ["#test"] });
    simulateEvent(hook, "submit_nick_change", {});
    expect(storage.store["rhc_reconnect_state"]).toBeUndefined();
  });
});
