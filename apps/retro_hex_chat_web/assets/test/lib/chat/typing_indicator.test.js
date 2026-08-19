import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  TYPING_STOP_DELAY_MS,
  createTypingIndicator,
} from "../../../js/lib/chat/typing_indicator.js";

function fakeClock() {
  let pending = null;
  return {
    setTimeoutFn: (fn) => {
      pending = fn;
      return 1;
    },
    clearTimeoutFn: () => {
      pending = null;
    },
    tick: () => {
      const fn = pending;
      pending = null;
      if (fn) fn();
    },
  };
}

describe("createTypingIndicator", () => {
  let clock;
  let onStart;
  let onStop;

  beforeEach(() => {
    clock = fakeClock();
    onStart = vi.fn();
    onStop = vi.fn();
  });

  const make = () =>
    createTypingIndicator({
      onStart,
      onStop,
      setTimeoutFn: clock.setTimeoutFn,
      clearTimeoutFn: clock.clearTimeoutFn,
    });

  it("starts on the first keystroke only", () => {
    const t = make();
    t.keystroke();
    t.keystroke();
    expect(onStart).toHaveBeenCalledTimes(1);
    expect(t.active).toBe(true);
  });

  it("stops after the lull", () => {
    const t = make();
    t.keystroke();
    clock.tick();
    expect(onStop).toHaveBeenCalledTimes(1);
    expect(t.active).toBe(false);
  });

  it("re-arms the lull on each keystroke", () => {
    const t = make();
    t.keystroke();
    t.keystroke(); // resets the timer
    expect(onStop).not.toHaveBeenCalled();
    clock.tick();
    expect(onStop).toHaveBeenCalledTimes(1);
  });

  it("stop() reports a stop only when typing", () => {
    const t = make();
    t.stop();
    expect(onStop).not.toHaveBeenCalled();

    t.keystroke();
    t.stop();
    expect(onStop).toHaveBeenCalledTimes(1);
    expect(t.active).toBe(false);
  });

  it("does not fire a second stop after an explicit stop", () => {
    const t = make();
    t.keystroke();
    t.stop();
    clock.tick(); // the timer was cleared
    expect(onStop).toHaveBeenCalledTimes(1);
  });

  it("exposes the default delay", () => {
    expect(TYPING_STOP_DELAY_MS).toBe(3000);
  });
});
