/**
 * This browser's side of a push subscription.
 *
 * Every path here ends in a plain object rather than an exception, because the
 * caller is a checkbox: it has to be able to say "on", "off", or why not, and
 * none of those is a stack trace.
 */
import { beforeEach, describe, expect, it, vi } from "vitest";

import { createPushSubscriptions } from "../../../js/lib/notifications/push_subscriptions.js";

const PUBLIC_KEY =
  "BApTG0Lu9QwSEbcXeIGQAKKGWYD6cvCPGS8Qbg2ZvhJ1lmFAPPwqQ5YFE4IWzB6xg4qZ3JZ4x8TQqEPKQ4AYbCk";

function subscriptionStub(endpoint = "https://push.example/abc") {
  return {
    endpoint,
    toJSON: () => ({ endpoint, keys: { p256dh: "p256dh-value", auth: "auth-value" } }),
    unsubscribe: vi.fn(() => Promise.resolve(true)),
  };
}

function navStub(pushManager) {
  return {
    userAgent: "Test/1.0",
    serviceWorker: { ready: Promise.resolve({ pushManager }) },
  };
}

beforeEach(() => {
  globalThis.PushManager = function PushManagerStub() {};
});

describe("current", () => {
  it("says nothing is supported without a service worker", async () => {
    const push = createPushSubscriptions({ nav: {} });

    expect(await push.current()).toEqual({ supported: false, subscribed: false });
  });

  it("reports an existing subscription", async () => {
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(subscriptionStub()) }),
    });

    expect(await push.current()).toEqual({ supported: true, subscribed: true });
  });

  it("reports the absence of one", async () => {
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(null) }),
    });

    expect(await push.current()).toEqual({ supported: true, subscribed: false });
  });
});

describe("subscribe", () => {
  it("hands back the endpoint and both keys", async () => {
    const subscribe = vi.fn(() => Promise.resolve(subscriptionStub()));
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(null), subscribe }),
    });

    const result = await push.subscribe(PUBLIC_KEY);

    expect(result.ok).toBe(true);
    expect(result.subscription).toEqual({
      endpoint: "https://push.example/abc",
      p256dh: "p256dh-value",
      auth: "auth-value",
      user_agent: "Test/1.0",
    });
  });

  // Browsers refuse a subscription that promises to show nothing, and a silent
  // push is exactly what the refusal exists to prevent.
  it("always promises the push will be visible", async () => {
    const subscribe = vi.fn(() => Promise.resolve(subscriptionStub()));
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(null), subscribe }),
    });

    await push.subscribe(PUBLIC_KEY);

    expect(subscribe).toHaveBeenCalledWith(expect.objectContaining({ userVisibleOnly: true }));
  });

  it("reuses a subscription the browser already had", async () => {
    const subscribe = vi.fn();
    const push = createPushSubscriptions({
      nav: navStub({
        getSubscription: () => Promise.resolve(subscriptionStub("https://push.example/old")),
        subscribe,
      }),
    });

    const result = await push.subscribe(PUBLIC_KEY);

    expect(subscribe).not.toHaveBeenCalled();
    expect(result.subscription.endpoint).toBe("https://push.example/old");
  });

  it("names a refusal as a refusal", async () => {
    const error = new Error("no");
    error.name = "NotAllowedError";
    const push = createPushSubscriptions({
      nav: navStub({
        getSubscription: () => Promise.resolve(null),
        subscribe: () => Promise.reject(error),
      }),
    });

    expect(await push.subscribe(PUBLIC_KEY)).toEqual({ ok: false, reason: "denied" });
  });

  // A server with no VAPID keys has nothing to subscribe to, and the browser
  // must not be asked for permission on its behalf.
  it("refuses to ask when the server has no key", async () => {
    const subscribe = vi.fn();
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(null), subscribe }),
    });

    expect(await push.subscribe(null)).toEqual({ ok: false, reason: "unconfigured" });
    expect(subscribe).not.toHaveBeenCalled();
  });

  it("says so when the browser cannot do this at all", async () => {
    const push = createPushSubscriptions({ nav: {} });

    expect(await push.subscribe(PUBLIC_KEY)).toEqual({ ok: false, reason: "unsupported" });
  });
});

describe("unsubscribe", () => {
  it("gives up the subscription and names it", async () => {
    const existing = subscriptionStub("https://push.example/bye");
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(existing) }),
    });

    expect(await push.unsubscribe()).toEqual({ ok: true, endpoint: "https://push.example/bye" });
    expect(existing.unsubscribe).toHaveBeenCalled();
  });

  it("is content when there was nothing to give up", async () => {
    const push = createPushSubscriptions({
      nav: navStub({ getSubscription: () => Promise.resolve(null) }),
    });

    expect(await push.unsubscribe()).toEqual({ ok: true, endpoint: null });
  });
});
