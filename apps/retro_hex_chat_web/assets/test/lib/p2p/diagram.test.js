import { describe, expect, it } from "vitest";

import {
  DEFAULT_CYCLE_MS,
  DEFAULT_DOT_COUNT,
  diagramConfig,
  dotFrame,
  dotPosition,
} from "../../../js/lib/p2p/diagram.js";

describe("dotPosition", () => {
  it("moves left-to-right by default", () => {
    expect(dotPosition("ltr", 0, 0)).toBe(0);
    expect(dotPosition("ltr", 0.25, 0)).toBe(0.25);
  });

  it("reverses for rtl", () => {
    expect(dotPosition("rtl", 0.25, 0)).toBe(0.75);
    expect(dotPosition("rtl", 0, 0)).toBe(1);
  });

  it("bounces for bidi: out on the first half, back on the second", () => {
    expect(dotPosition("bidi", 0, 0)).toBe(0);
    expect(dotPosition("bidi", 0.25, 0)).toBeCloseTo(0.5);
    expect(dotPosition("bidi", 0.5, 0)).toBeCloseTo(1);
    expect(dotPosition("bidi", 0.75, 0)).toBeCloseTo(0.5);
  });

  it("wraps with the phase offset", () => {
    expect(dotPosition("ltr", 0.9, 0.2)).toBeCloseTo(0.1);
  });
});

describe("dotFrame", () => {
  it("places a dot as a left percentage at full opacity", () => {
    const frame = dotFrame({
      direction: "ltr",
      progress: 0.5,
      index: 0,
      dotCount: 3,
      isAudio: false,
    });
    expect(frame.left).toBe("50%");
    expect(frame.opacity).toBe("1");
    expect(frame.width).toBeUndefined();
  });

  it("adds size and vertical wave in audio mode", () => {
    const frame = dotFrame({
      direction: "ltr",
      progress: 0.1,
      index: 1,
      dotCount: 3,
      isAudio: true,
    });
    expect(frame.width).toMatch(/px$/);
    expect(frame.height).toBe(frame.width);
    expect(frame.top).toMatch(/px$/);
  });

  it("offsets successive dots by index/dotCount", () => {
    const a = dotFrame({ direction: "ltr", progress: 0, index: 0, dotCount: 4, isAudio: false });
    const b = dotFrame({ direction: "ltr", progress: 0, index: 1, dotCount: 4, isAudio: false });
    expect(a.left).toBe("0%");
    expect(b.left).toBe("25%");
  });
});

describe("diagramConfig", () => {
  it("uses defaults when the dataset is empty", () => {
    const c = diagramConfig({}, false);
    expect(c.dotCount).toBe(DEFAULT_DOT_COUNT);
    expect(c.cycleMs).toBe(DEFAULT_CYCLE_MS);
    expect(c.direction).toBe("none");
    expect(c.needsDots).toBe(false);
  });

  it("parses dot count and cycle from the dataset", () => {
    const c = diagramConfig(
      { dots: "5", cycleMs: "800", state: "transferring", direction: "rtl" },
      false,
    );
    expect(c.dotCount).toBe(5);
    expect(c.cycleMs).toBe(800);
    expect(c.needsDots).toBe(true);
  });

  it("needs dots only for animated states", () => {
    for (const state of ["transferring", "video-call", "audio-call"]) {
      expect(diagramConfig({ state }, false).needsDots).toBe(true);
    }
    expect(diagramConfig({ state: "idle" }, false).needsDots).toBe(false);
  });

  it("suppresses dots under reduced motion", () => {
    expect(diagramConfig({ state: "transferring" }, true).needsDots).toBe(false);
  });
});
