import { describe, expect, it, vi } from "vitest";
import { createDesktopNotifyHook } from "../../../js/hooks/notifications/desktop_notify_hook.js";

function mountHook(notifier) {
  const handlers = {};
  const pushEvent = vi.fn();
  const hook = createDesktopNotifyHook({ createNotifier: () => notifier });

  const context = {
    handleEvent: (name, fn) => {
      handlers[name] = fn;
    },
    pushEvent,
  };

  hook.mounted.call(context);

  return { handlers, pushEvent, hook, context };
}

function fakeNotifier(permission = "granted") {
  return {
    permission: () => permission,
    request: vi.fn(async () => "granted"),
    notify: vi.fn(),
    destroy: vi.fn(),
  };
}

describe("desktop notify hook", () => {
  it("reports the current permission on mount so the dialog can draw it", () => {
    const { pushEvent } = mountHook(fakeNotifier("denied"));

    expect(pushEvent).toHaveBeenCalledWith("desktop_notify_permission", {
      permission: "denied",
    });
  });

  it("hands a server notification straight to the notifier", () => {
    const notifier = fakeNotifier();
    const { handlers } = mountHook(notifier);

    handlers.desktop_notify({ title: "#retro", body: "hi", tag: "#retro" });

    expect(notifier.notify).toHaveBeenCalledWith(
      { title: "#retro", body: "hi", tag: "#retro" },
      expect.any(Function),
    );
  });

  it("tells the server which conversation was clicked", () => {
    const notifier = fakeNotifier();
    const { handlers, pushEvent } = mountHook(notifier);

    handlers.desktop_notify({ title: "#retro", body: "hi", tag: "#retro" });
    const [, onClick] = notifier.notify.mock.calls[0];
    onClick("#retro");

    expect(pushEvent).toHaveBeenCalledWith("desktop_notify_click", {
      conversation: "#retro",
    });
  });

  // The prompt must follow a gesture, so it happens on the server's request
  // event — which only fires from the person ticking the box — never on mount.
  it("never asks for permission on its own", () => {
    const notifier = fakeNotifier("default");
    mountHook(notifier);

    expect(notifier.request).not.toHaveBeenCalled();
  });

  it("asks when the person asks, and reports the answer back", async () => {
    const notifier = fakeNotifier("default");
    const { handlers, pushEvent } = mountHook(notifier);

    await handlers.desktop_notify_request_permission();

    expect(notifier.request).toHaveBeenCalledTimes(1);
    expect(pushEvent).toHaveBeenLastCalledWith("desktop_notify_permission", {
      permission: "granted",
    });
  });

  it("closes what it opened when the hook goes away", () => {
    const notifier = fakeNotifier();
    const { hook, context } = mountHook(notifier);

    hook.destroyed.call(context);

    expect(notifier.destroy).toHaveBeenCalled();
  });
});
