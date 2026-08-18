import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  LONG_PRESS_MS,
  MOVE_TOLERANCE_PX,
  createLongPress,
} from "../../../js/lib/input/long_press.js";

// A controllable clock: start() records the callback, tick() runs it.
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
    get armed() {
      return pending !== null;
    },
  };
}

describe("createLongPress", () => {
  let clock;
  let onFire;

  beforeEach(() => {
    clock = fakeClock();
    onFire = vi.fn();
  });

  function machine(extra = {}) {
    return createLongPress({
      onFire,
      setTimeoutFn: clock.setTimeoutFn,
      clearTimeoutFn: clock.clearTimeoutFn,
      ...extra,
    });
  }

  it("fires once after the hold, with the start context", () => {
    const lp = machine();
    lp.start(10, 10, { nick: "alice" });
    expect(onFire).not.toHaveBeenCalled();

    clock.tick();
    expect(onFire).toHaveBeenCalledWith({ nick: "alice" });
    expect(lp.fired).toBe(true);
    expect(lp.suppressNextClick).toBe(true);
  });

  it("cancels when the finger drifts past the tolerance", () => {
    const lp = machine();
    lp.start(0, 0, {});
    lp.move(0, MOVE_TOLERANCE_PX + 1);

    expect(clock.armed).toBe(false);
    clock.tick();
    expect(onFire).not.toHaveBeenCalled();
  });

  it("tolerates drift within the tolerance", () => {
    const lp = machine();
    lp.start(0, 0, {});
    lp.move(MOVE_TOLERANCE_PX, -MOVE_TOLERANCE_PX);

    expect(clock.armed).toBe(true);
    clock.tick();
    expect(onFire).toHaveBeenCalled();
  });

  it("ignores movement once it has fired", () => {
    const lp = machine();
    lp.start(0, 0, {});
    clock.tick();
    lp.move(1000, 1000); // way past tolerance, but already fired
    expect(lp.fired).toBe(true);
  });

  it("finish() reports whether it had fired and keeps click suppression", () => {
    const lp = machine();
    lp.start(0, 0, {});
    clock.tick();

    expect(lp.finish()).toBe(true);
    expect(lp.suppressNextClick).toBe(true);
    expect(lp.active).toBe(false);
  });

  it("finish() before firing reports false", () => {
    const lp = machine();
    lp.start(0, 0, {});
    expect(lp.finish()).toBe(false);
  });

  it("cancel clears click suppression unless asked to keep it", () => {
    const lp = machine();
    lp.start(0, 0, {});
    clock.tick();
    expect(lp.suppressNextClick).toBe(true);

    lp.cancel();
    expect(lp.suppressNextClick).toBe(false);
  });

  it("consumeClickSuppression returns and clears the flag", () => {
    const lp = machine();
    lp.suppressNextClick = true;
    expect(lp.consumeClickSuppression()).toBe(true);
    expect(lp.suppressNextClick).toBe(false);
    expect(lp.consumeClickSuppression()).toBe(false);
  });

  it("shouldFire can decline at fire time, cancelling instead", () => {
    const lp = machine({ shouldFire: (ctx) => ctx.connected });
    lp.start(0, 0, { connected: false });
    clock.tick();

    expect(onFire).not.toHaveBeenCalled();
    expect(lp.fired).toBe(false);
    expect(lp.suppressNextClick).toBe(false);
  });

  it("shouldFire returning true fires normally", () => {
    const lp = machine({ shouldFire: () => true });
    lp.start(0, 0, {});
    clock.tick();
    expect(onFire).toHaveBeenCalled();
  });

  it("a fresh start cancels a press already in flight", () => {
    const lp = machine();
    lp.start(0, 0, { first: true });
    lp.start(5, 5, { second: true });
    clock.tick();

    expect(onFire).toHaveBeenCalledTimes(1);
    expect(onFire).toHaveBeenCalledWith({ second: true });
  });

  it("exposes the shared default constants", () => {
    expect(LONG_PRESS_MS).toBe(550);
    expect(MOVE_TOLERANCE_PX).toBe(10);
  });
});
