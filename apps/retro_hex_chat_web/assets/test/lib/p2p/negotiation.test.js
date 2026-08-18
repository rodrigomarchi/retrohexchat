import { describe, expect, it } from "vitest";

import {
  advanceEpoch,
  canApplyDescription,
  isStaleEpoch,
  nextConnectionEpoch,
  normalizeEpoch,
  ownsDescription,
} from "../../../js/lib/p2p/negotiation.js";

describe("ownsDescription", () => {
  it("owns nothing filtered until a role is assigned", () => {
    expect(ownsDescription(null, "offer")).toBe(true);
    expect(ownsDescription(undefined, "answer")).toBe(true);
  });

  it("the initiator applies answers, the answerer applies offers", () => {
    expect(ownsDescription("initiator", "answer")).toBe(true);
    expect(ownsDescription("initiator", "offer")).toBe(false);
    expect(ownsDescription("answerer", "offer")).toBe(true);
    expect(ownsDescription("answerer", "answer")).toBe(false);
  });
});

describe("canApplyDescription", () => {
  const states = [
    "stable",
    "have-local-offer",
    "have-remote-offer",
    "have-local-pranswer",
    "have-remote-pranswer",
    "closed",
  ];

  it("accepts an offer only in stable or have-remote-offer", () => {
    for (const state of states) {
      const expected = state === "stable" || state === "have-remote-offer";
      expect(canApplyDescription(state, "offer")).toBe(expected);
    }
  });

  it("accepts an answer only in have-local-offer", () => {
    for (const state of states) {
      expect(canApplyDescription(state, "answer")).toBe(state === "have-local-offer");
    }
  });
});

describe("normalizeEpoch", () => {
  it("keeps positive integers", () => {
    expect(normalizeEpoch(3)).toBe(3);
    expect(normalizeEpoch("5")).toBe(5);
  });

  it("rejects zero, negatives, fractions and junk", () => {
    for (const value of [0, -1, 1.5, "x", null, undefined, NaN, {}]) {
      expect(normalizeEpoch(value)).toBeNull();
    }
  });
});

describe("nextConnectionEpoch", () => {
  it("adopts a requested epoch at or above the current", () => {
    expect(nextConnectionEpoch(4, 4)).toBe(4);
    expect(nextConnectionEpoch(4, 7)).toBe(7);
  });

  it("steps past the current when the request is older or absent", () => {
    expect(nextConnectionEpoch(4, 2)).toBe(5);
    expect(nextConnectionEpoch(4, null)).toBe(5);
  });
});

describe("advanceEpoch", () => {
  it("jumps to a strictly greater requested epoch", () => {
    expect(advanceEpoch(4, 9)).toBe(9);
  });

  it("otherwise steps by one", () => {
    expect(advanceEpoch(4, 4)).toBe(5);
    expect(advanceEpoch(4, 1)).toBe(5);
    expect(advanceEpoch(4, undefined)).toBe(5);
  });
});

describe("isStaleEpoch", () => {
  it("is true for an epoch older than the current", () => {
    expect(isStaleEpoch(5, 3)).toBe(true);
  });

  it("is false at or above the current, or before any epoch is set", () => {
    expect(isStaleEpoch(5, 5)).toBe(false);
    expect(isStaleEpoch(5, 8)).toBe(false);
    expect(isStaleEpoch(0, 3)).toBe(false);
    expect(isStaleEpoch(5, null)).toBe(false);
  });
});
