import { describe, expect, it } from "vitest";

import {
  canDeferRecovery,
  hasExhaustedRecovery,
  hasExhaustedWatchdog,
  isDisconnectedReason,
  nextRecoveryAttempt,
  recoveryBackoffDelay,
  watchdogDelay,
} from "../../../js/lib/p2p/recovery.js";

describe("recoveryBackoffDelay", () => {
  const ladder = [1000, 2000, 4000];
  it("steps up the ladder by attempt", () => {
    expect(recoveryBackoffDelay(1, ladder)).toBe(1000);
    expect(recoveryBackoffDelay(2, ladder)).toBe(2000);
    expect(recoveryBackoffDelay(3, ladder)).toBe(4000);
  });
  it("clamps past the last step", () => {
    expect(recoveryBackoffDelay(9, ladder)).toBe(4000);
  });
});

describe("nextRecoveryAttempt", () => {
  it("advances when the attempt counts", () => {
    expect(nextRecoveryAttempt(2, true)).toBe(3);
  });
  it("holds at the current, or 1 the first time, when it does not count", () => {
    expect(nextRecoveryAttempt(2, false)).toBe(2);
    expect(nextRecoveryAttempt(0, false)).toBe(1);
  });
});

describe("hasExhaustedRecovery / hasExhaustedWatchdog", () => {
  it("is true at or past the max", () => {
    expect(hasExhaustedRecovery(3, 3)).toBe(true);
    expect(hasExhaustedRecovery(2, 3)).toBe(false);
    expect(hasExhaustedWatchdog(3, 3)).toBe(true);
    expect(hasExhaustedWatchdog(1, 3)).toBe(false);
  });
});

describe("isDisconnectedReason", () => {
  it("matches only the two disconnect reasons", () => {
    expect(isDisconnectedReason("disconnected")).toBe(true);
    expect(isDisconnectedReason("ice_disconnected")).toBe(true);
    expect(isDisconnectedReason("failed")).toBe(false);
    expect(isDisconnectedReason("auto_retry")).toBe(false);
  });
});

describe("canDeferRecovery", () => {
  it("allows deferrals below the limit", () => {
    expect(canDeferRecovery(0, 2)).toBe(true);
    expect(canDeferRecovery(1, 2)).toBe(true);
    expect(canDeferRecovery(2, 2)).toBe(false);
  });
});

describe("watchdogDelay", () => {
  it("grows linearly with the attempt", () => {
    expect(watchdogDelay(1, 1500)).toBe(1500);
    expect(watchdogDelay(3, 1500)).toBe(4500);
  });
});
