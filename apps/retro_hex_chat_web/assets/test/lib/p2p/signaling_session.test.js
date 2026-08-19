import {
  canScheduleSignalReplay,
  signalReplayDelay,
  needsSignalReplay,
  canScheduleRenegotiationRetry,
  renegotiationRetryDelay,
  isFinalRenegotiationAttempt,
  canDeferDisconnectedRecovery,
} from "../../../js/lib/p2p/signaling_session.js";

describe("canScheduleSignalReplay", () => {
  it("allows a run only with no pending timer and attempts remaining", () => {
    expect(canScheduleSignalReplay(0, 3, false)).toBe(true);
    expect(canScheduleSignalReplay(2, 3, false)).toBe(true);
    expect(canScheduleSignalReplay(3, 3, false)).toBe(false);
    expect(canScheduleSignalReplay(0, 3, true)).toBe(false);
  });
});

describe("signalReplayDelay", () => {
  it("backs off linearly with the attempt number", () => {
    expect(signalReplayDelay(1, 1500)).toBe(1500);
    expect(signalReplayDelay(3, 1500)).toBe(4500);
  });
});

describe("needsSignalReplay", () => {
  const base = {
    hasPc: true,
    connectionState: "connecting",
    iceConnectionState: "checking",
    recoveryFailed: false,
  };

  it("is false with no pc or after recovery gave up", () => {
    expect(needsSignalReplay({ ...base, hasPc: false })).toBe(false);
    expect(needsSignalReplay({ ...base, recoveryFailed: true })).toBe(false);
  });

  it("is false once connected or ICE-completed", () => {
    expect(needsSignalReplay({ ...base, connectionState: "connected" })).toBe(false);
    expect(needsSignalReplay({ ...base, iceConnectionState: "completed" })).toBe(false);
  });

  it("is true for a live, still-negotiating connection", () => {
    expect(needsSignalReplay(base)).toBe(true);
  });
});

describe("canScheduleRenegotiationRetry", () => {
  it("allows only the answerer, with no pending timer and attempts remaining", () => {
    expect(canScheduleRenegotiationRetry("answerer", 0, 3, false)).toBe(true);
    expect(canScheduleRenegotiationRetry("initiator", 0, 3, false)).toBe(false);
    expect(canScheduleRenegotiationRetry("answerer", 3, 3, false)).toBe(false);
    expect(canScheduleRenegotiationRetry("answerer", 0, 3, true)).toBe(false);
  });
});

describe("renegotiationRetryDelay", () => {
  it("backs off linearly with the attempt number", () => {
    expect(renegotiationRetryDelay(1, 1200)).toBe(1200);
    expect(renegotiationRetryDelay(2, 1200)).toBe(2400);
  });
});

describe("isFinalRenegotiationAttempt", () => {
  it("is true only on the last allowed attempt", () => {
    expect(isFinalRenegotiationAttempt(2, 3)).toBe(false);
    expect(isFinalRenegotiationAttempt(3, 3)).toBe(true);
    expect(isFinalRenegotiationAttempt(4, 3)).toBe(true);
  });
});

describe("canDeferDisconnectedRecovery", () => {
  it("allows a deferral only below the limit", () => {
    expect(canDeferDisconnectedRecovery(0, 2)).toBe(true);
    expect(canDeferDisconnectedRecovery(1, 2)).toBe(true);
    expect(canDeferDisconnectedRecovery(2, 2)).toBe(false);
  });
});
