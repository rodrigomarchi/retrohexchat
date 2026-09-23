import { describe, expect, it, vi } from "vitest";
import { createDesktopNotifier } from "../../../js/lib/notifications/desktop_notifier.js";

function fakeApi(permission = "granted") {
  const raised = [];

  class FakeNotification {
    constructor(title, options) {
      this.title = title;
      this.options = options;
      this.closed = false;
      this.onclick = null;
      raised.push(this);
    }

    close() {
      this.closed = true;
    }
  }

  FakeNotification.permission = permission;
  FakeNotification.requestPermission = vi.fn(async () => "granted");

  return { FakeNotification, raised };
}

const hidden = { hidden: true };
const visible = { hidden: false };

describe("desktop notifier", () => {
  it("raises a notification when the tab is in the background", () => {
    const { FakeNotification, raised } = fakeApi();
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: hidden,
    });

    expect(notifier.notify({ title: "#retro", body: "ana: hi", tag: "#retro" })).toBe("shown");
    expect(raised).toHaveLength(1);
    expect(raised[0].options.body).toBe("ana: hi");
  });

  // The row is already on screen; saying it again in a system popup is noise.
  it("stays quiet while the tab is in front", () => {
    const { FakeNotification, raised } = fakeApi();
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: visible,
    });

    expect(notifier.notify({ title: "#retro", body: "ana: hi", tag: "#retro" })).toBe("visible");
    expect(raised).toHaveLength(0);
  });

  it("does nothing without permission, and never asks on its own", () => {
    const { FakeNotification, raised } = fakeApi("denied");
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: hidden,
    });

    expect(notifier.notify({ title: "#retro", body: "ana: hi", tag: "#retro" })).toBe("denied");
    expect(raised).toHaveLength(0);
    expect(FakeNotification.requestPermission).not.toHaveBeenCalled();
  });

  it("does not ask again once refused", async () => {
    const { FakeNotification } = fakeApi("denied");
    const notifier = createDesktopNotifier({ notification: FakeNotification });

    expect(await notifier.request()).toBe("denied");
    expect(FakeNotification.requestPermission).not.toHaveBeenCalled();
  });

  it("asks exactly once while permission is still unset", async () => {
    const { FakeNotification } = fakeApi("default");
    const notifier = createDesktopNotifier({ notification: FakeNotification });

    expect(await notifier.request()).toBe("granted");
    expect(FakeNotification.requestPermission).toHaveBeenCalledTimes(1);
  });

  // A busy room would otherwise stack one popup per line.
  it("replaces the previous notification for the same conversation", () => {
    const { FakeNotification, raised } = fakeApi();
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: hidden,
    });

    notifier.notify({ title: "#retro", body: "first", tag: "#retro" });
    notifier.notify({ title: "#retro", body: "second", tag: "#retro" });

    expect(raised).toHaveLength(2);
    expect(raised[0].closed).toBe(true);
    expect(raised[1].closed).toBe(false);
  });

  it("keeps notifications for different conversations apart", () => {
    const { FakeNotification, raised } = fakeApi();
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: hidden,
    });

    notifier.notify({ title: "#a", body: "x", tag: "#a" });
    notifier.notify({ title: "#b", body: "y", tag: "#b" });

    expect(raised.every((n) => !n.closed)).toBe(true);
  });

  it("hands the conversation back when the person clicks", () => {
    const { FakeNotification, raised } = fakeApi();
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: hidden,
    });
    const onClick = vi.fn();

    notifier.notify({ title: "#retro", body: "hi", tag: "#retro" }, onClick);
    raised[0].onclick();

    expect(onClick).toHaveBeenCalledWith("#retro");
    expect(raised[0].closed).toBe(true);
  });

  it("closes everything it opened on destroy", () => {
    const { FakeNotification, raised } = fakeApi();
    const notifier = createDesktopNotifier({
      notification: FakeNotification,
      doc: hidden,
    });

    notifier.notify({ title: "#a", body: "x", tag: "#a" });
    notifier.notify({ title: "#b", body: "y", tag: "#b" });
    notifier.destroy();

    expect(raised.every((n) => n.closed)).toBe(true);
  });

  it("reports the API as unsupported rather than throwing", () => {
    const notifier = createDesktopNotifier({ notification: undefined, doc: hidden });

    expect(notifier.permission()).toBe("unsupported");
    expect(notifier.notify({ title: "a", body: "b", tag: "c" })).toBe("unsupported");
  });
});
