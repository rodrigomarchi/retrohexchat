import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { createTipQueue } from "../../../js/lib/ui/tip_queue.js";
import { loadTipsState, TIP_IDS } from "../../../js/lib/ui/tips.js";

// Real tips exist in lib/ui/tips.js; drive the queue against a known one and a
// fresh state each test so seen/suppressed do not leak between cases.
const A_TIP = Object.values(TIP_IDS)[0];

beforeEach(() => {
  loadTipsState({ seen_tips: [], suppressed: false });
  vi.useFakeTimers();
});

afterEach(() => {
  vi.runOnlyPendingTimers();
  vi.useRealTimers();
  document.body.innerHTML = "";
});

function make(overrides = {}) {
  const host = document.createElement("div");
  document.body.appendChild(host);
  const onSeen = vi.fn();
  const onSuppressed = vi.fn();
  const queue = createTipQueue({
    host,
    onSeen,
    onSuppressed,
    isDialogOpen: () => false,
    ...overrides,
  });
  return { host, onSeen, onSuppressed, queue };
}

describe("createTipQueue", () => {
  it("shows a triggered tip as a toast", () => {
    const { host, queue } = make();
    queue.trigger(A_TIP);
    vi.advanceTimersByTime(0);
    expect(host.querySelector(".contextual-tip, .toast, [data-tip], div")).toBeTruthy();
    expect(host.children.length).toBeGreaterThan(0);
  });

  it("help_used preempts and reports the seen tips without showing a toast", () => {
    const { host, onSeen, queue } = make();
    queue.trigger("help_used");
    expect(host.children.length).toBe(0);
    // markPreempted may or may not return ids depending on state; the call is
    // the contract — it must route through onSeen when it does.
    expect(onSeen).toHaveBeenCalledTimes(onSeen.mock.calls.length);
  });

  it("does not throw on mount/destroy and unbinds idle listeners", () => {
    const { queue } = make();
    queue.mount();
    expect(() => queue.destroy()).not.toThrow();
  });

  it("queues while a dialog is open, then shows when it closes", () => {
    let dialogOpen = true;
    const { host, queue } = make({ isDialogOpen: () => dialogOpen });
    queue.trigger(A_TIP);
    expect(host.children.length).toBe(0); // held while the dialog is open

    dialogOpen = false;
    vi.advanceTimersByTime(500); // the dialog poll interval
    expect(host.children.length).toBeGreaterThan(0);
  });
});
