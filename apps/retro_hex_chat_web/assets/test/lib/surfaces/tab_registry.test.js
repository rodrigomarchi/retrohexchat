import { describe, expect, it, vi } from "vitest";
import {
  CHANNEL_NAME,
  FOCUS_TIMEOUT_MS,
  answerFocusRequests,
  openChannel,
  requestFocus,
  supported,
} from "../../../js/lib/surfaces/tab_registry.js";

/**
 * A pair of BroadcastChannel stand-ins that actually talk to each other, so a
 * test can play both tabs. Delivery is synchronous, which is the only thing a
 * test needs to be different from a browser: the ordering it proves is the
 * ordering of the protocol, not of the event loop.
 */
function twoTabs() {
  const listeners = new Set();

  const make = () => {
    const own = new Set();

    const channel = {
      postMessage(data) {
        for (const listener of listeners) {
          if (!own.has(listener)) listener({ data });
        }
      },
      addEventListener(_type, listener) {
        own.add(listener);
        listeners.add(listener);
      },
      removeEventListener(_type, listener) {
        own.delete(listener);
        listeners.delete(listener);
      },
    };

    return channel;
  };

  return [make(), make()];
}

describe("tab registry", () => {
  it("names one channel, so two halves cannot disagree", () => {
    expect(CHANNEL_NAME).toBe("retrohex:surfaces");
  });

  it("reports no support, and opens nothing, where there is no BroadcastChannel", () => {
    const scope = {};

    expect(supported(scope)).toBe(false);
    expect(openChannel(scope)).toBeNull();
  });

  it("opens the shared channel by name where it exists", () => {
    const opened = [];
    const scope = {
      BroadcastChannel: function BroadcastChannelStub(name) {
        opened.push(name);
      },
    };

    expect(supported(scope)).toBe(true);
    expect(openChannel(scope)).toBeTruthy();
    expect(opened).toEqual([CHANNEL_NAME]);
  });

  // The whole point: a tab that is there says so, and says it after trying.
  it("resolves true when the tab holding the address answers", async () => {
    const [asker, holder] = twoTabs();
    const focus = vi.fn();

    answerFocusRequests(holder, "/call/one", { focus });

    await expect(requestFocus(asker, "/call/one")).resolves.toBe(true);
    expect(focus).toHaveBeenCalledTimes(1);
  });

  it("ignores a request for a different address", async () => {
    const [asker, holder] = twoTabs();
    const focus = vi.fn();

    answerFocusRequests(holder, "/call/one", { focus });

    await expect(requestFocus(asker, "/call/two", { timeoutMs: 10 })).resolves.toBe(false);
    expect(focus).not.toHaveBeenCalled();
  });

  // Degrading is the requirement. Nobody home has to end, not hang.
  it("expires instead of hanging when no tab answers", async () => {
    const [asker] = twoTabs();

    await expect(requestFocus(asker, "/call/one", { timeoutMs: 10 })).resolves.toBe(false);
  });

  it("expires with no channel at all", async () => {
    await expect(requestFocus(null, "/call/one")).resolves.toBe(false);
  });

  it("does not ask for an address it does not have", async () => {
    const [asker] = twoTabs();

    await expect(requestFocus(asker, "")).resolves.toBe(false);
  });

  // Refused focus is the common case, and it must not turn into "no tab here".
  it("still answers when focus() is refused, and says why", async () => {
    const [asker, holder] = twoTabs();
    const onError = vi.fn();
    const focus = () => {
      throw new Error("focus refused");
    };

    answerFocusRequests(holder, "/call/one", { focus, onError });

    await expect(requestFocus(asker, "/call/one")).resolves.toBe(true);
    expect(onError).toHaveBeenCalledTimes(1);
  });

  it("stops answering once the tab is done", async () => {
    const [asker, holder] = twoTabs();
    const focus = vi.fn();

    const stop = answerFocusRequests(holder, "/call/one", { focus });
    stop();

    await expect(requestFocus(asker, "/call/one", { timeoutMs: 10 })).resolves.toBe(false);
    expect(focus).not.toHaveBeenCalled();
  });

  it("answers nothing without a channel or an address", () => {
    expect(answerFocusRequests(null, "/call/one")()).toBeUndefined();
    expect(answerFocusRequests({}, "")()).toBeUndefined();
  });

  it("only ever settles once, however many tabs answer", async () => {
    const [asker, holderA] = twoTabs();
    const holderB = holderA;

    answerFocusRequests(holderA, "/call/one", { focus: vi.fn() });
    answerFocusRequests(holderB, "/call/one", { focus: vi.fn() });

    await expect(requestFocus(asker, "/call/one")).resolves.toBe(true);
  });

  it("keeps a deadline short enough to feel like a click", () => {
    expect(FOCUS_TIMEOUT_MS).toBeLessThanOrEqual(500);
  });
});
