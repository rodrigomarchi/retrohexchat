/**
 * What the service worker does when a push arrives, and when one is clicked.
 *
 * The worker is not importable — it is a standalone script served from the
 * root, and it has to stay one, because a bundled module worker would be a
 * build artifact where a checked-in file is what every environment serves. So
 * it is evaluated here against a fake `self`, and driven through the same two
 * listeners the browser drives it through. That tests the shipped file rather
 * than a copy of its decisions.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

import { beforeEach, describe, expect, it, vi } from "vitest";

const SW_PATH = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../../priv/static/sw.js",
);

function loadWorker() {
  const listeners = {};
  const registration = { showNotification: vi.fn(() => Promise.resolve()) };
  const clients = {
    matchAll: vi.fn(() => Promise.resolve([])),
    openWindow: vi.fn(() => Promise.resolve()),
    claim: vi.fn(() => Promise.resolve()),
  };

  const self = {
    addEventListener: (name, handler) => {
      listeners[name] = handler;
    },
    skipWaiting: () => Promise.resolve(),
    location: { origin: "https://chat.example" },
    registration,
    clients,
  };

  const context = {
    self,
    caches: { keys: () => Promise.resolve([]), open: () => Promise.resolve({}) },
    fetch: vi.fn(),
    URL,
    encodeURIComponent,
    console,
  };

  vm.runInNewContext(fs.readFileSync(SW_PATH, "utf8"), context);

  return { listeners, registration, clients };
}

// The browser hands a listener an event and waits on whatever it is given.
// Collecting that promise is what lets a test await the work the worker did.
function dispatch(handler, event) {
  let waited = Promise.resolve();
  handler({ ...event, waitUntil: (promise) => (waited = promise) });
  return waited;
}

describe("push", () => {
  let worker;

  beforeEach(() => {
    worker = loadWorker();
  });

  it("raises a notification carrying the conversation", async () => {
    await dispatch(worker.listeners.push, {
      data: { json: () => ({ title: "#lobby", body: "Ana: hey", conversation: "#lobby" }) },
    });

    expect(worker.registration.showNotification).toHaveBeenCalledWith(
      "#lobby",
      expect.objectContaining({
        body: "Ana: hey",
        tag: "#lobby",
        data: { conversation: "#lobby" },
      }),
    );
  });

  // A room that was busy while the tab was closed is one thing to come back to.
  it("tags by conversation so a busy room stays one notification", async () => {
    await dispatch(worker.listeners.push, {
      data: { json: () => ({ title: "#lobby", body: "one", conversation: "#lobby" }) },
    });
    await dispatch(worker.listeners.push, {
      data: { json: () => ({ title: "#lobby", body: "two", conversation: "#lobby" }) },
    });

    const tags = worker.registration.showNotification.mock.calls.map(([, options]) => options.tag);
    expect(tags).toEqual(["#lobby", "#lobby"]);
  });

  it("still says something when the payload is unreadable", async () => {
    await dispatch(worker.listeners.push, {
      data: {
        json: () => {
          throw new Error("not json");
        },
      },
    });

    expect(worker.registration.showNotification).toHaveBeenCalledWith(
      "Retro Hex Chat",
      expect.objectContaining({ body: "" }),
    );
  });

  it("still says something when there is no payload at all", async () => {
    await dispatch(worker.listeners.push, {});

    expect(worker.registration.showNotification).toHaveBeenCalledWith(
      "Retro Hex Chat",
      expect.anything(),
    );
  });
});

describe("notificationclick", () => {
  let worker;

  beforeEach(() => {
    worker = loadWorker();
  });

  function clickEvent(conversation) {
    return {
      notification: { close: vi.fn(), data: { conversation } },
    };
  }

  it("opens the conversation when nothing is open", async () => {
    await dispatch(worker.listeners.notificationclick, clickEvent("#lobby"));

    expect(worker.clients.openWindow).toHaveBeenCalledWith("/chat?conversation=%23lobby");
  });

  // A second window beside the one they already have is not what anybody meant
  // by clicking a notification.
  it("raises a window already on the chat instead of opening another", async () => {
    const focus = vi.fn(() => Promise.resolve());
    const navigate = vi.fn(() => Promise.resolve());
    worker.clients.matchAll.mockResolvedValue([
      { url: "https://chat.example/chat", focus, navigate },
    ]);

    await dispatch(worker.listeners.notificationclick, clickEvent("#lobby"));

    expect(focus).toHaveBeenCalled();
    expect(navigate).toHaveBeenCalledWith("/chat?conversation=%23lobby");
    expect(worker.clients.openWindow).not.toHaveBeenCalled();
  });

  // Focusing somebody's unrelated tab is worse than opening a new one.
  it("ignores a window that is not on the chat", async () => {
    worker.clients.matchAll.mockResolvedValue([
      { url: "https://chat.example/how-it-works", focus: vi.fn() },
    ]);

    await dispatch(worker.listeners.notificationclick, clickEvent("#lobby"));

    expect(worker.clients.openWindow).toHaveBeenCalledWith("/chat?conversation=%23lobby");
  });

  it("opens the chat when the notification names no conversation", async () => {
    await dispatch(worker.listeners.notificationclick, { notification: { close: vi.fn() } });

    expect(worker.clients.openWindow).toHaveBeenCalledWith("/chat");
  });

  it("dismisses the notification it was given", async () => {
    const event = clickEvent("#lobby");
    await dispatch(worker.listeners.notificationclick, event);

    expect(event.notification.close).toHaveBeenCalled();
  });
});
