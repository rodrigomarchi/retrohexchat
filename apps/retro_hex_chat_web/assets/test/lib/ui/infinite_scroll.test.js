import { afterEach, describe, expect, it, vi } from "vitest";

import {
  DEFAULT_THRESHOLD_PX,
  createScrollIntent,
  didOverrun,
  isNearEdge,
  parseThreshold,
} from "../../../js/lib/ui/infinite_scroll.js";

const el = ({ scrollTop = 0, scrollHeight = 1000, clientHeight = 200 }) => ({
  scrollTop,
  scrollHeight,
  clientHeight,
});

describe("isNearEdge", () => {
  it("is near the top within the threshold", () => {
    expect(isNearEdge(el({ scrollTop: 50 }), "top", 100)).toBe(true);
    expect(isNearEdge(el({ scrollTop: 150 }), "top", 100)).toBe(false);
  });

  it("is near the bottom within the threshold", () => {
    // distance to bottom = 1000 - 750 - 200 = 50
    expect(isNearEdge(el({ scrollTop: 750 }), "bottom", 100)).toBe(true);
    expect(isNearEdge(el({ scrollTop: 500 }), "bottom", 100)).toBe(false);
  });
});

describe("didOverrun", () => {
  it("is true only for a jump that lands on the edge", () => {
    // jump > clientHeight (200) landing at top 0
    expect(didOverrun(el({ scrollHeight: 1000 }), "top", 900, 0)).toBe(true);
    // small move, no overrun
    expect(didOverrun(el({}), "top", 50, 0)).toBe(false);
  });

  it("detects a bottom overrun", () => {
    // land at scrollHeight - clientHeight = 800, from far away
    expect(didOverrun(el({ scrollTop: 800 }), "bottom", 100, 800)).toBe(true);
  });
});

describe("parseThreshold", () => {
  it("parses a non-negative integer", () => {
    expect(parseThreshold("250")).toBe(250);
    expect(parseThreshold("0")).toBe(0);
  });

  it("falls back to the default for junk or negatives", () => {
    expect(parseThreshold("")).toBe(DEFAULT_THRESHOLD_PX);
    expect(parseThreshold("-5")).toBe(DEFAULT_THRESHOLD_PX);
    expect(parseThreshold(undefined)).toBe(DEFAULT_THRESHOLD_PX);
  });
});

describe("createScrollIntent", () => {
  afterEach(() => vi.useRealTimers());

  it("marks active and expires after the window", () => {
    vi.useFakeTimers();
    const intent = createScrollIntent(1000);
    expect(intent.active).toBe(false);
    intent.mark();
    expect(intent.active).toBe(true);
    vi.advanceTimersByTime(1000);
    expect(intent.active).toBe(false);
  });

  it("markFromKey only reacts to gesture keys", () => {
    vi.useFakeTimers();
    const intent = createScrollIntent();
    intent.markFromKey("a");
    expect(intent.active).toBe(false);
    intent.markFromKey("PageDown");
    expect(intent.active).toBe(true);
  });

  it("clear cancels the active window", () => {
    vi.useFakeTimers();
    const intent = createScrollIntent();
    intent.mark();
    intent.clear();
    expect(intent.active).toBe(false);
  });
});
